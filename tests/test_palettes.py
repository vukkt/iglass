"""Palette checks: rechecks every contrast promise against the shipped data/palette.json.

Run: python3 -m unittest discover -s tests -p 'test_*.py'
"""

import importlib.util
import json
import os
import plistlib
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("build", os.path.join(ROOT, "tools", "build_palettes.py"))
build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(build)

with open(os.path.join(ROOT, "design", "palettes.json")) as f:
    DESIGN = json.load(f)
with open(os.path.join(ROOT, "data", "palette.json")) as f:
    PALETTE = json.load(f)

MODES = ("dark", "light")

# Each contrast level: (design with that level's targets, its colors in data/palette.json).
LEVELS = {
    "standard": (DESIGN, PALETTE),
    "high": (build.with_targets(DESIGN, DESIGN["contrast"]["highContrastTargets"]), PALETTE["highContrast"]),
}


def rgb(color):
    return tuple(int(round(color[c] * 255)) for c in ("Red Component", "Green Component", "Blue Component"))


def backgrounds(mode, colors=PALETTE):
    bg = rgb(colors["modes"][mode]["Background Color"])
    return [build.blend(build.hex_to_rgb(d), bg, DESIGN["variants"][v]["transparency"])
            for tier in DESIGN["contrast"]["tiers"] for v in tier["variants"] for d in tier["desktops"]]


class ColorMath(unittest.TestCase):
    def test_contrast_extremes(self):
        self.assertAlmostEqual(build.contrast((0, 0, 0), (255, 255, 255)), 21.0, places=2)
        self.assertAlmostEqual(build.contrast((119, 119, 119), (119, 119, 119)), 1.0)

    def test_oklch_round_trip(self):
        for hexc in ("#FF453A", "#0040DD", "#1D1D1F", "#F5F5F7", "#32D74B"):
            c = build.hex_to_rgb(hexc)
            back = build.oklch_to_rgb(*build.rgb_to_oklch(c))
            for a, b in zip(c, back):
                self.assertLessEqual(abs(a - b), 1, hexc)

    def test_adjust_keeps_passing_colors(self):
        white = (255, 255, 255)
        self.assertEqual(build.adjust(white, [([(0, 0, 0)], 7.0)], lighten=True), white)

    def test_adjust_moves_the_right_way(self):
        dark_bg = [(23, 24, 28)]
        out = build.adjust((10, 132, 255), [(dark_bg, 6.0)], lighten=True)
        self.assertGreaterEqual(build.min_contrast(out, dark_bg), 6.0)
        self.assertGreater(build.luminance(out), build.luminance((10, 132, 255)))

    def test_adjust_reports_impossible_targets(self):
        with self.assertRaises(build.PaletteError):
            build.adjust((128, 128, 128), [([(128, 128, 128)], 22.0)], lighten=True)


class GeneratedFiles(unittest.TestCase):
    def test_generated_files_are_up_to_date(self):
        self.assertEqual(build.main(["--check"]), 0,
                         "run python3 tools/build_palettes.py and commit the result")

    def test_itermcolors_presets_parse(self):
        for mode in MODES:
            with open(os.path.join(ROOT, "themes", "iglass-%s.itermcolors" % mode), "rb") as f:
                colors = plistlib.load(f)
            for i in range(16):
                self.assertIn("Ansi %d Color" % i, colors)
            self.assertIn("Background Color", colors)


class Contrast(unittest.TestCase):
    """Every promise in the contrast report, for both the standard and high-contrast palettes."""

    def levels(self):
        for level, (design, colors) in LEVELS.items():
            with self.subTest(level=level):
                yield level, design, design["contrast"]["targets"], colors

    def test_foreground(self):
        for level, design, t, colors in self.levels():
            for mode in MODES:
                fg = rgb(colors["modes"][mode]["Foreground Color"])
                self.assertGreaterEqual(build.min_contrast(fg, backgrounds(mode, colors)), t["foreground"],
                                        "%s %s" % (level, mode))

    def test_ansi_colors(self):
        for level, design, t, colors in self.levels():
            for mode in MODES:
                bgs = backgrounds(mode, colors)
                for i, name in enumerate(build.ANSI_ORDER):
                    target = build.ansi_target(design, mode, name)
                    if target is None:
                        continue
                    c = rgb(colors["modes"][mode]["Ansi %d Color" % i])
                    self.assertGreaterEqual(build.min_contrast(c, bgs), target, "%s %s %s" % (level, mode, name))

    def test_normal_colors_on_solid_background(self):
        for level, design, t, colors in self.levels():
            for mode in MODES:
                bg = rgb(colors["modes"][mode]["Background Color"])
                for name in build.NORMAL_CHROMATIC:
                    c = rgb(colors["modes"][mode]["Ansi %d Color" % build.ANSI_ORDER.index(name)])
                    self.assertGreaterEqual(build.contrast(c, bg), t["ansiNormalOnSolid"],
                                            "%s %s %s" % (level, mode, name))

    def test_bright_colors_are_visibly_lighter(self):
        for level, design, t, colors in self.levels():
            gap = t["brightLightnessGap"] - 0.005
            for mode in MODES:
                for normal, bright in build.bright_pairs(design, mode):
                    ln = build.rgb_to_oklch(rgb(colors["modes"][mode]["Ansi %d Color" % build.ANSI_ORDER.index(normal)]))[0]
                    lb = build.rgb_to_oklch(rgb(colors["modes"][mode]["Ansi %d Color" % build.ANSI_ORDER.index(bright)]))[0]
                    self.assertGreaterEqual(lb - ln, gap, "%s %s %s/%s" % (level, mode, normal, bright))

    def test_accents(self):
        for level, design, t, colors in self.levels():
            for name, acc in colors["accents"].items():
                for mode in MODES:
                    bgs = backgrounds(mode, colors)
                    bg = rgb(colors["modes"][mode]["Background Color"])
                    fg = rgb(colors["modes"][mode]["Foreground Color"])
                    link = rgb(acc[mode]["Link Color"])
                    where = "%s %s %s" % (level, mode, name)
                    self.assertGreaterEqual(build.min_contrast(link, bgs), t["link"], where)
                    self.assertGreaterEqual(build.contrast(link, bg), t["linkOnSolid"], where)
                    self.assertGreaterEqual(build.min_contrast(rgb(acc[mode]["Cursor Color"]), bgs), t["cursor"], where)
                    self.assertGreaterEqual(build.contrast(fg, rgb(acc[mode]["Selection Color"])), t["selectionText"], where)

    def test_find_highlight_keeps_text_readable(self):
        for level, design, t, colors in self.levels():
            for mode in MODES:
                fg = rgb(colors["modes"][mode]["Foreground Color"])
                find = rgb(colors["modes"][mode]["Match Background Color"])
                self.assertGreaterEqual(build.contrast(fg, find), t["findText"], "%s %s" % (level, mode))

    def test_high_contrast_is_actually_stronger(self):
        for mode in MODES:
            bgs = backgrounds(mode)
            for i, name in enumerate(build.ANSI_ORDER):
                if build.ansi_target(DESIGN, mode, name) is None:
                    continue
                std = build.min_contrast(rgb(PALETTE["modes"][mode]["Ansi %d Color" % i]), bgs)
                hc = build.min_contrast(rgb(PALETTE["highContrast"]["modes"][mode]["Ansi %d Color" % i]), bgs)
                self.assertGreaterEqual(hc + 1e-9, std, "%s %s" % (mode, name))


class Variants(unittest.TestCase):
    def test_guids_are_unique_uuids(self):
        guids = [v["guid"] for v in PALETTE["variants"].values()] + [PALETTE["custom"]["guid"]]
        self.assertEqual(len(guids), len(set(guids)))
        for g in guids:
            self.assertRegex(g, r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")

    def test_glass_levels_are_ordered(self):
        t = [PALETTE["variants"][v]["transparency"] for v in ("clear", "frosted", "tinted", "solid")]
        self.assertEqual(t, sorted(t, reverse=True))
        self.assertEqual(PALETTE["variants"]["solid"]["transparency"], 0)
        self.assertFalse(PALETTE["variants"]["solid"]["blur"])

    def test_blur_within_iterm_limits(self):
        for v in PALETTE["variants"].values():
            self.assertLessEqual(v["blurRadius"], PALETTE["limits"]["blurRadiusWarn"])

    def test_min_safe_opacity_is_tight(self):
        """The guaranteed variants sit at or above the safe minimum, and it is not overly cautious."""
        m = PALETTE["limits"]["minSafeOpacity"]
        for v in ("frosted", "tinted", "solid"):
            self.assertGreaterEqual(round(1 - PALETTE["variants"][v]["transparency"], 2), m, v)
        self.assertLess(m, 1 - PALETTE["variants"]["tinted"]["transparency"])


class Docs(unittest.TestCase):
    def test_report_mentions_every_accent(self):
        with open(os.path.join(ROOT, "docs", "contrast-report.md")) as f:
            report = f.read()
        for name in PALETTE["accentOrder"]:
            self.assertRegex(report, re.compile(r"^\| %s \|" % name, re.M))


if __name__ == "__main__":
    unittest.main()
