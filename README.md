<div align="center">

# iglass

**A Liquid Glass–inspired theme for iTerm2.**
Translucent, softly blurred, built from Apple's system colors, and contrast-checked so it stays readable.

[![CI](https://github.com/vukkt/iglass/actions/workflows/ci.yml/badge.svg)](https://github.com/vukkt/iglass/actions/workflows/ci.yml)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-black)
![iTerm2 3.5+](https://img.shields.io/badge/iTerm2-3.5%2B-black)
![License: MIT](https://img.shields.io/badge/license-MIT-black)

<img src="docs/screenshots/frosted.png" width="49%" alt="iglass Frosted in dark mode">
<img src="docs/screenshots/frosted-light.png" width="49%" alt="iglass Frosted in light mode">

<sub>iglass Frosted in dark and light mode, over a colorful wallpaper.</sub>

</div>

## Why iglass

macOS's Liquid Glass makes apps feel light and layered. iTerm2 can't use Apple's real glass
material (see [the FAQ](#is-this-real-liquid-glass)), but it can get close: transparency,
background blur, and a palette designed to sit on top of them. iglass does that carefully:

- **Four glass levels**, mirroring Apple's own options: Clear, Frosted, Tinted and Solid.
- **Follows light and dark mode** automatically, with a separate palette for each.
- **Apple's system colors** and macOS accent colors, adjusted only where contrast requires it.
- **Contrast-checked.** Every color is verified against the window *as it looks over your
  desktop*, not just against a flat background. [See the report.](docs/contrast-report.md)
- **High-contrast option** and hints for macOS Reduce Transparency / Increase Contrast.
- **Keeps your setup.** Only the look changes: your font, keyboard shortcuts, shell and
  directories stay as they are.
- **Safe and reversible.** App-wide changes are opt-in, backed up, and restored exactly on
  uninstall.

## Variants

| | Dark | Light |
|---|---|---|
| **Clear** | <img src="docs/screenshots/clear.png" alt="iglass Clear, dark"> | <img src="docs/screenshots/clear-light.png" alt="iglass Clear, light"> |
| **Frosted** | <img src="docs/screenshots/frosted.png" alt="iglass Frosted, dark"> | <img src="docs/screenshots/frosted-light.png" alt="iglass Frosted, light"> |
| **Tinted** | <img src="docs/screenshots/tinted.png" alt="iglass Tinted, dark"> | <img src="docs/screenshots/tinted-light.png" alt="iglass Tinted, light"> |
| **Solid** | <img src="docs/screenshots/solid.png" alt="iglass Solid, dark"> | <img src="docs/screenshots/solid-light.png" alt="iglass Solid, light"> |

| Variant | Feels like | Transparency | Readable over |
|---|---|---|---|
| **Clear** | Liquid Glass *Clear* | 50% | Mid-tone wallpapers (aesthetic choice) |
| **Frosted** · default | Liquid Glass *Regular* | 34% | Typical wallpapers |
| **Tinted** | macOS *Tinted* mode | 18% | Any wallpaper |
| **Solid** | Reduce Transparency | 0% | Any wallpaper |

Accents: blue, purple, pink, red, orange, yellow, green, graphite (the macOS accent colors).

## Install

**Requirements:** macOS 15 or later and [iTerm2](https://iterm2.com) 3.5 or later.

With Homebrew:

```sh
brew install vukkt/tap/iglass
iglass install
```

From source (works with any checkout):

```sh
git clone https://github.com/vukkt/iglass.git
cd iglass && ./install.sh --local
iglass install
```

Or with the install script, which downloads the latest release (puts `iglass` in `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/vukkt/iglass/main/install.sh | bash
iglass install
```

Then open a window with `iglass preview`, or choose **Profiles › iglass Frosted** in iTerm2.

<details>
<summary>Without the CLI</summary>

Copy [`themes/iglass.json`](themes/iglass.json) into
`~/Library/Application Support/iTerm2/DynamicProfiles/`. iTerm2 picks it up immediately.
Plain color presets are in [`themes/`](themes) too (iTerm2 › Settings › Profiles › Colors ›
Color Presets › Import), but they carry colors only, not the glass settings.

</details>

## Usage

```sh
iglass install                          # all four variants, blue accent
iglass install --accent purple          # pick an accent
iglass install --contrast high          # stronger colors
iglass install --app-settings           # native title bar + roomier padding (restarts iTerm2)
iglass install --variant tinted --default   # make a variant your default profile

iglass preview --variant clear          # open a window to try a variant
iglass list                             # variants and accents
iglass status                           # what's installed
iglass doctor                           # check for problems (changes nothing)
iglass uninstall                        # remove everything, restore settings
```

### Fine-tuning

```sh
iglass install --opacity 0.8 --blur 18      # adds an "iglass Custom" profile
iglass install --cursor box                  # bar (default), box, underline, keep
iglass install --window no-titlebar          # native (default), no-titlebar, keep
iglass install --font sf-mono                # keep (default), sf-mono, or "PostScriptName 14"
iglass export --accent green > my.json       # print the profiles file instead
```

Opacity below the readable minimum (0.66) asks for `--force`.

### App-wide settings

Some of the native feel comes from iTerm2 settings that apply to every window, not just a
profile: iTerm2's **Automatic** theme, which lets macOS draw the title bar and tabs the way it
draws them for its own apps, and generous **padding**. Apple's Liquid Glass guidance asks apps
to let the system draw bars rather than custom ones.
`--app-settings` turns these on. Because iTerm2 saves its settings when it quits, iglass has
to change them while iTerm2 is closed:

1. iglass records the current values and backs up your iTerm2 preferences.
2. A small helper quits iTerm2 (it asks first if programs are running), applies the change and
   reopens it. If you cancel the quit, nothing is written.
3. `iglass uninstall` restores the exact previous values and removes keys that didn't exist.

Backups live in `~/Library/Application Support/iglass/backups`.

## How it works

iglass installs an iTerm2 [dynamic profile](https://iterm2.com/documentation-dynamic-profiles.html):
one JSON file holding the four variants. A dynamic profile inherits everything it doesn't set
from your default profile, so iglass sets every color and every setting iTerm2 keeps
separately for light and dark mode (a test enforces this), and nothing about how you work.

The colors come from a small build pipeline:

1. [`design/palettes.json`](design/palettes.json) holds Apple's system colors, the variants and
   the contrast targets.
2. [`tools/build_palettes.py`](tools/build_palettes.py) blends each window background over
   black, white and grey desktops at each variant's transparency, checks every color against
   the worst case, and nudges lightness (in OKLCH, keeping hue) only where a color falls short.
3. The result ships as [`data/palette.json`](data/palette.json), and every decision is listed
   in the [contrast report](docs/contrast-report.md).

The CLI is plain bash plus the `jq`, `plutil` and `defaults` that ship with macOS, so there is
nothing else to install. Files are written atomically and validated with Apple's own parser
first, because one unreadable file stops iTerm2 from loading *any* dynamic profile.

More detail, including what was verified in iTerm2's source: [docs/research-notes.md](docs/research-notes.md).

## FAQ

### Is this real Liquid Glass?

No, and nothing can be from a theme today. Liquid Glass is a system material apps adopt in
their own code. iTerm2 hasn't shipped it: a
[pull request adding it](https://github.com/gnachman/iTerm2/pull/767) was closed because glass
breaks window resizing in a terminal. iglass gets as close as iTerm2 allows with transparency,
blur and a matching palette. If iTerm2 adds real glass later, iglass will use it.

### Isn't glass behind text against Apple's own advice?

Partly. Apple reserves glass for controls and navigation and keeps content clear. Terminal text
*is* content, which is why Frosted is the default, Tinted and Solid exist, and every variant is
contrast-checked. Choose the level that suits you; Tinted is the most Apple-like for long work.

### My prompt icons disappeared.

iglass keeps your font unless you pass `--font`. If you did, reinstall without it
(`iglass install`) to go back to your own (e.g. a Nerd Font).

### Text is hard to read on my wallpaper.

Use a lower glass level (`iglass preview --variant tinted`), or `--contrast high`.

### iglass profiles don't show up in iTerm2.

Run `iglass doctor`. The most common cause is *another* broken file in the dynamic profiles
folder, which stops iTerm2 from loading all of them.

## Uninstall

```sh
iglass uninstall            # removes the profiles; asks to restore app-wide settings
brew uninstall iglass       # or: curl -fsSL …/install.sh | bash -s -- --uninstall
```

## Development

```sh
make palettes   # rebuild colors after editing design/palettes.json
make check      # shellcheck, generated-file check, palette tests, bats suite
tools/screenshots.sh   # README screenshots over a generated backdrop (needs Screen Recording)
```

Tests run in a sandbox with stand-ins for iTerm2 and system commands, so they never touch
your real settings. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

iglass is an independent project, not affiliated with or endorsed by Apple Inc. or iTerm2.
Liquid Glass, macOS and SF Mono are trademarks of Apple Inc. MIT licensed.
