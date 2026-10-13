#!/usr/bin/env python3
"""Build iglass color data from design/palettes.json.

Reads the human-edited design file and writes:
  data/palette.json          final colors + variant settings, read by the iglass CLI at runtime
  docs/contrast-report.md    every color, its contrast, and any adjustment the build made
  themes/*.itermcolors       plain color presets for people who don't use the CLI

Base colors are Apple system colors. Where one is not readable enough on top of a translucent
window, its OKLCH lightness is nudged (hue and chroma kept as far as sRGB allows) until it meets
the contrast target in every scenario. Nothing is adjusted silently: the report lists each change.

Standard library only (runs on the python3 that ships with the Xcode command line tools).
Usage: python3 tools/build_palettes.py [--check]
  --check   build in memory and exit 1 if any generated file is out of date (used by CI)
"""

import json
import math
import os
import plistlib
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = os.path.join(ROOT, "design", "palettes.json")
OUT_PALETTE = os.path.join(ROOT, "data", "palette.json")
OUT_REPORT = os.path.join(ROOT, "docs", "contrast-report.md")
OUT_THEMES = os.path.join(ROOT, "themes")

ANSI_ORDER = [
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "brightBlack", "brightRed", "brightGreen", "brightYellow",
    "brightBlue", "brightMagenta", "brightCyan", "brightWhite",
]
NORMAL_CHROMATIC = ["red", "green", "yellow", "blue", "magenta", "cyan"]


class PaletteError(Exception):
    pass


# --- color math -----------------------------------------------------------------------------

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6:
        raise PaletteError("bad hex color: #%s" % h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb):
    return "#%02X%02X%02X" % tuple(rgb)


def _decode(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _encode(c):
    c = max(0.0, min(1.0, c))
    v = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return v * 255.0


def luminance(rgb):
    r, g, b = (_decode(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def blend(top, bottom, alpha):
    """Composite `top` at `alpha` over `bottom` in gamma-encoded sRGB, as the window server does."""
    return tuple(int(round(alpha * t + (1 - alpha) * b)) for t, b in zip(top, bottom))


def rgb_to_oklch(rgb):
    r, g, b = (_decode(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return L, math.hypot(a, bb), math.atan2(bb, a)


def _oklch_to_linear(L, C, h):
    a, b = C * math.cos(h), C * math.sin(h)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def oklch_to_rgb(L, C, h):
    """OKLCH to 8-bit sRGB, reducing chroma until the color fits in the sRGB gamut."""
    def in_gamut(lin):
        return all(-1e-6 <= c <= 1 + 1e-6 for c in lin)

    lin = _oklch_to_linear(L, C, h)
    if not in_gamut(lin):
        lo, hi = 0.0, C
        for _ in range(40):
            mid = (lo + hi) / 2
            if in_gamut(_oklch_to_linear(L, mid, h)):
                lo = mid
            else:
                hi = mid
        lin = _oklch_to_linear(L, lo, h)
    return tuple(int(round(_encode(c))) for c in lin)


# --- contrast scenarios ---------------------------------------------------------------------

def scenario_backgrounds(design, mode, transparencies=None):
    """Every effective background text can sit on: the window color blended over each desktop."""
    bg = hex_to_rgb(design["modes"][mode]["background"])
    con = design["contrast"]
    scenes = []
    if transparencies is None:
        for tier in con["tiers"]:
            for name in tier["variants"]:
                t = design["variants"][name]["transparency"]
                for d in tier["desktops"]:
                    scenes.append(("%s over %s" % (name, d), blend(hex_to_rgb(d), bg, t)))
    else:
        for t in transparencies:
            for d in con["safeOpacityDesktops"]:
                scenes.append(("t=%.2f over %s" % (t, d), blend(hex_to_rgb(d), bg, t)))
    return scenes


def min_contrast(rgb, backgrounds):
    return min(contrast(rgb, b) for b in backgrounds)


def adjust(rgb, checks, lighten):
    """Return the color closest to `rgb` (by OKLCH lightness) that passes every check.

    `checks` is a list of (backgrounds, target). Lightens on dark backgrounds, darkens on light.
    """
    def passes(c):
        return all(min_contrast(c, bgs) >= target for bgs, target in checks)

    if passes(rgb):
        return rgb
    L, C, h = rgb_to_oklch(rgb)
    lo, hi = (L, 1.0) if lighten else (0.0, L)
    edge = oklch_to_rgb(hi if lighten else lo, C, h)
    if not passes(edge):
        raise PaletteError("cannot reach contrast target for %s" % rgb_to_hex(rgb))
    for _ in range(50):
        mid = (lo + hi) / 2
        ok = passes(oklch_to_rgb(mid, C, h))
        if lighten:
            hi, lo = (mid, lo) if ok else (hi, mid)
        else:
            lo, hi = (mid, hi) if ok else (lo, mid)
    best = oklch_to_rgb(hi if lighten else lo, C, h)
    if not passes(best):  # 8-bit rounding can land a hair short
        raise PaletteError("rounding left %s short of target" % rgb_to_hex(best))
    return best


# --- build ----------------------------------------------------------------------------------

def iterm_color(rgb, alpha=1.0):
    return {
        "Alpha Component": round(alpha, 6),
        "Blue Component": round(rgb[2] / 255.0, 6),
        "Color Space": "sRGB",
        "Green Component": round(rgb[1] / 255.0, 6),
        "Red Component": round(rgb[0] / 255.0, 6),
    }


def ansi_key(i):
    return "Ansi %d Color" % i


def build_mode(design, mode, report):
    spec = design["modes"][mode]
    con = design["contrast"]
    targets = con["targets"]
    lighten = mode == "dark"
    bg = hex_to_rgb(spec["background"])
    scenes = scenario_backgrounds(design, mode)
    all_bgs = [b for _, b in scenes]

    colors = {}
    rows = []

    def record(role, base, final, bgs, target):
        rows.append({
            "role": role, "base": rgb_to_hex(base), "final": rgb_to_hex(final),
            "contrast": round(min_contrast(final, bgs), 2), "target": target,
            "adjusted": base != final,
        })

    fg_base = hex_to_rgb(spec["foreground"])
    fg = adjust(fg_base, [(all_bgs, targets["foreground"])], lighten)
    record("Foreground", fg_base, fg, all_bgs, targets["foreground"])

    ansi = {}
    for name in ANSI_ORDER:
        base = hex_to_rgb(spec["ansi"][name])
        target = ansi_target(design, mode, name)
        if target is None:
            ansi[name] = base
            continue
        checks = [(all_bgs, target)]
        if name in NORMAL_CHROMATIC:
            checks.append(([bg], targets["ansiNormalOnSolid"]))
        ansi[name] = adjust(base, checks, lighten)

    enforce_bright_gap(design, mode, ansi)

    for i, name in enumerate(ANSI_ORDER):
        base = hex_to_rgb(spec["ansi"][name])
        target = ansi_target(design, mode, name)
        if target is None:
            rows.append({"role": "ANSI %d %s" % (i, name), "base": rgb_to_hex(base),
                         "final": rgb_to_hex(base), "contrast": None, "target": "exempt",
                         "adjusted": False})
        else:
            record("ANSI %d %s" % (i, name), base, ansi[name], all_bgs, target)

    find_base = hex_to_rgb(spec["find"])
    find = _tint_for_text(find_base, bg, fg, con["findAlpha"][mode], targets["findText"])

    colors["Background Color"] = iterm_color(bg)
    colors["Foreground Color"] = iterm_color(fg)
    colors["Bold Color"] = iterm_color(fg)
    colors["Cursor Text Color"] = iterm_color(bg)
    colors["Selected Text Color"] = iterm_color(fg)
    colors["Underline Color"] = iterm_color(fg)
    colors["Match Background Color"] = iterm_color(find)
    for i, name in enumerate(ANSI_ORDER):
        colors[ansi_key(i)] = iterm_color(ansi[name])

    report[mode] = {"rows": rows, "scenes": [(n, rgb_to_hex(b)) for n, b in scenes]}
    return colors, {"bg": bg, "fg": fg, "ansi": ansi, "all_bgs": all_bgs, "lighten": lighten}


def ansi_target(design, mode, name):
    """Contrast target for an ANSI slot, or None if the slot is exempt."""
    con = design["contrast"]
    if name in con["exempt"][mode]:
        return None
    if name in con["muted"][mode]:
        return con["targets"]["ansiMuted"]
    group = "ansiBright" if name.startswith("bright") else "ansiNormal"
    return con["targets"][group][mode]


def bright_pairs(design, mode):
    """(normal, bright) slot pairs that must stay visibly different."""
    con = design["contrast"]
    skip = set(con["exempt"][mode]) | set(con["muted"][mode])
    pairs = []
    for name in ANSI_ORDER[:8]:
        bright = "bright" + name[0].upper() + name[1:]
        if name not in skip and bright not in skip:
            pairs.append((name, bright))
    return pairs


def enforce_bright_gap(design, mode, ansi):
    """Keep each bright color at least `brightLightnessGap` lighter (OKLCH L) than its normal.

    Dark mode lightens the bright color; light mode darkens the normal one. Both moves only
    increase contrast against the background, so earlier targets still hold.
    """
    gap = design["contrast"]["targets"]["brightLightnessGap"]
    for normal, bright in bright_pairs(design, mode):
        ln, cn, hn = rgb_to_oklch(ansi[normal])
        lb, cb, hb = rgb_to_oklch(ansi[bright])
        if lb - ln >= gap:
            continue
        if mode == "dark":
            ansi[bright] = oklch_to_rgb(min(1.0, ln + gap + 0.002), cb, hb)
        else:
            ansi[normal] = oklch_to_rgb(max(0.0, lb - gap - 0.002), cn, hn)
        ln, lb = rgb_to_oklch(ansi[normal])[0], rgb_to_oklch(ansi[bright])[0]
        if lb - ln < gap - 0.005:  # allow for 8-bit rounding
            raise PaletteError("%s mode: %s and %s are too close in lightness"
                               % (mode, normal, bright))


def _tint_for_text(tint, bg, fg, alpha, target):
    """Blend `tint` over `bg`, lowering alpha until `fg` text on it meets `target`."""
    a = alpha
    while a > 0:
        c = blend(tint, bg, a)
        if contrast(fg, c) >= target:
            return c
        a = round(a - 0.01, 2)
    return bg


def build_accent(design, mode, ctx, accent_hex, rows):
    con = design["contrast"]
    targets = con["targets"]
    base = hex_to_rgb(accent_hex)
    all_bgs, bg, lighten = ctx["all_bgs"], ctx["bg"], ctx["lighten"]

    link = adjust(base, [(all_bgs, targets["link"]), ([bg], targets["linkOnSolid"])], lighten)
    cursor = adjust(base, [(all_bgs, targets["cursor"])], lighten)
    selection = _tint_for_text(base, bg, ctx["fg"], con["selectionAlpha"][mode],
                               targets["selectionText"])
    rows.append((rgb_to_hex(base), rgb_to_hex(link), round(min_contrast(link, all_bgs), 2),
                 rgb_to_hex(cursor), rgb_to_hex(selection),
                 round(contrast(ctx["fg"], selection), 2)))
    return {
        "Cursor Color": iterm_color(cursor),
        "IME Cursor Color": iterm_color(cursor),
        "Active Pane Border Color": iterm_color(base),
        "Link Color": iterm_color(link),
        "Selection Color": iterm_color(selection),
        "Cursor Guide Color": iterm_color(base, 0.25),
        "Badge Color": iterm_color(base, 0.5),
        "Tab Color": iterm_color(base),
    }, {"link": link, "cursor": cursor}


def safe_opacity(design, final):
    """Lowest opacity (1 - transparency) at which every color still meets its target
    over both black and white desktops. Custom --opacity below this triggers a warning."""
    targets = design["contrast"]["targets"]

    def ok(t):
        for mode, ctx in final.items():
            bgs = [b for _, b in scenario_backgrounds(design, mode, [t])]
            if min_contrast(ctx["fg"], bgs) < targets["foreground"]:
                return False
            for name, rgb in ctx["ansi"].items():
                target = ansi_target(design, mode, name)
                if target is not None and min_contrast(rgb, bgs) < target:
                    return False
            for acc in ctx["accents"].values():
                if min_contrast(acc["link"], bgs) < targets["link"]:
                    return False
                if min_contrast(acc["cursor"], bgs) < targets["cursor"]:
                    return False
        return True

    lo, hi = 0.0, 1.0
    if not ok(lo):
        raise PaletteError("palette fails even when fully opaque")
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if ok(mid) else (lo, mid)
    return math.ceil((1 - lo) * 100) / 100


def validate_design(design):
    for mode in ("dark", "light"):
        spec = design["modes"][mode]
        missing = [n for n in ANSI_ORDER if n not in spec["ansi"]]
        if missing:
            raise PaletteError("%s mode is missing ANSI colors: %s" % (mode, ", ".join(missing)))
    for name, acc in design["accents"].items():
        if set(acc) != {"light", "dark"}:
            raise PaletteError("accent %s needs light and dark values" % name)
    guids = [v["guid"] for v in design["variants"].values()] + [design["custom"]["guid"]]
    if len(set(guids)) != len(guids):
        raise PaletteError("variant GUIDs must be unique")
    for name, v in design["variants"].items():
        if not 0 <= v["transparency"] < 1:
            raise PaletteError("variant %s: transparency must be in [0, 1)" % name)
        if not 0 <= v["blurRadius"] <= 64:
            raise PaletteError("variant %s: blurRadius must be in [0, 64]" % name)
    if design["defaultVariant"] not in design["variants"]:
        raise PaletteError("defaultVariant is not a variant")
    if design["defaultAccent"] not in design["accents"]:
        raise PaletteError("defaultAccent is not an accent")


def build(design):
    validate_design(design)
    report = {}
    modes, final = {}, {}
    for mode in ("dark", "light"):
        modes[mode], final[mode] = build_mode(design, mode, report)

    accents = {}
    for mode in ("dark", "light"):
        final[mode]["accents"] = {}
        report[mode]["accents"] = []
    for name, acc in design["accents"].items():
        accents[name] = {}
        for mode in ("dark", "light"):
            rows = []
            accents[name][mode], final[mode]["accents"][name] = build_accent(
                design, mode, final[mode], acc[mode], rows)
            report[mode]["accents"].append((name,) + rows[0])

    variants = {}
    for name, v in design["variants"].items():
        variants[name] = {k: v[k] for k in
                          ("name", "guid", "description", "transparency", "blur",
                           "blurRadius", "minimumContrast")}

    palette = {
        "$comment": "GENERATED by tools/build_palettes.py from design/palettes.json. Do not edit.",
        "schema": 1,
        "defaultVariant": design["defaultVariant"],
        "defaultAccent": design["defaultAccent"],
        "variantOrder": list(design["variants"]),
        "accentOrder": list(design["accents"]),
        "variants": variants,
        "custom": dict(design["custom"]),
        "limits": {
            "minSafeOpacity": safe_opacity(design, final),
            "blurRadiusMax": 64,
            "blurRadiusWarn": 26,
        },
        "modes": modes,
        "accents": accents,
    }
    return palette, report


def render_report(design, palette, report):
    lines = [
        "# Contrast report",
        "",
        "_Generated by `tools/build_palettes.py`. Do not edit by hand._",
        "",
        "Each color is checked against the window background blended over the desktop behind it:",
        "",
    ] + [
        "- **%s**: over %s" % (", ".join(v.capitalize() for v in tier["variants"]),
                               " and ".join("`%s`" % d for d in tier["desktops"]))
        for tier in design["contrast"]["tiers"]
    ] + [
        "",
        "Tinted and Solid hold up over any wallpaper. Frosted is checked over dark and light grey, "
        "standing in for typical blurred wallpapers. Clear is an aesthetic choice; at its "
        "translucency no palette can stay readable over every wallpaper.",
        "",
        "The **contrast** column is the worst case across those backgrounds (WCAG ratio). Base "
        "colors are Apple system colors; **adjusted** rows had their lightness nudged to meet "
        "the target.",
        "",
        "Custom `--opacity` values below **%.2f** can drop under these targets over typical "
        "wallpapers; iglass warns and asks for `--force`." % palette["limits"]["minSafeOpacity"],
        "",
    ]
    for mode in ("dark", "light"):
        r = report[mode]
        lines += ["## %s mode" % mode.capitalize(), "", "Backgrounds checked:", ""]
        lines += ["- %s → `%s`" % (n, h) for n, h in r["scenes"]]
        lines += ["", "| Role | Base | Final | Worst contrast | Target | Adjusted |",
                  "|---|---|---|---|---|---|"]
        for row in r["rows"]:
            c = "—" if row["contrast"] is None else "%.2f" % row["contrast"]
            t = row["target"] if isinstance(row["target"], str) else "%.1f" % row["target"]
            lines.append("| %s | `%s` | `%s` | %s | %s | %s |" % (
                row["role"], row["base"], row["final"], c, t, "yes" if row["adjusted"] else ""))
        lines += ["", "| Accent | Base | Link | Link contrast | Cursor | Selection | Text on selection |",
                  "|---|---|---|---|---|---|---|"]
        for name, base, link, lc, cursor, sel, sc in r["accents"]:
            lines.append("| %s | `%s` | `%s` | %.2f | `%s` | `%s` | %.2f |" % (
                name, base, link, lc, cursor, sel, sc))
        lines.append("")
    return "\n".join(lines)


def render_itermcolors(palette, mode, accent):
    colors = dict(palette["modes"][mode])
    colors.update(palette["accents"][accent][mode])
    return plistlib.dumps(colors, fmt=plistlib.FMT_XML, sort_keys=True)


def outputs(palette, report, design):
    files = {
        OUT_PALETTE: (json.dumps(palette, indent=2, sort_keys=False) + "\n").encode(),
        OUT_REPORT: (render_report(design, palette, report) + "\n").encode(),
    }
    accent = palette["defaultAccent"]
    for mode in ("dark", "light"):
        path = os.path.join(OUT_THEMES, "iglass-%s.itermcolors" % mode)
        files[path] = render_itermcolors(palette, mode, accent)
    return files


def main(argv):
    check = "--check" in argv
    with open(DESIGN) as f:
        design = json.load(f)
    try:
        palette, report = build(design)
    except PaletteError as e:
        print("build_palettes: %s" % e, file=sys.stderr)
        return 2
    stale = []
    for path, data in outputs(palette, report, design).items():
        rel = os.path.relpath(path, ROOT)
        try:
            with open(path, "rb") as f:
                current = f.read()
        except FileNotFoundError:
            current = None
        if current == data:
            continue
        if check:
            stale.append(rel)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        print("wrote %s" % rel)
    if stale:
        print("build_palettes: out of date (run python3 tools/build_palettes.py): %s"
              % ", ".join(stale), file=sys.stderr)
        return 1
    if not check:
        print("min safe opacity: %.2f" % palette["limits"]["minSafeOpacity"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
