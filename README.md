<div align="center">

# iglass

**A Liquid Glass theme for iTerm2 and Ghostty, on macOS and Linux.**
Translucent, built from Apple's system colors, and contrast-checked so it stays readable.
In Ghostty on macOS it uses Apple's real Liquid Glass material.

[![CI](https://github.com/vukkt/iglass/actions/workflows/ci.yml/badge.svg)](https://github.com/vukkt/iglass/actions/workflows/ci.yml)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-black)
![Linux](https://img.shields.io/badge/Linux-Ghostty-black)
![iTerm2 3.5+](https://img.shields.io/badge/iTerm2-3.5%2B-black)
![Ghostty 1.0+](https://img.shields.io/badge/Ghostty-1.0%2B-black)
![License: MIT](https://img.shields.io/badge/license-MIT-black)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-db61a2?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/vukkt)

<img src="docs/demo.gif" width="760" alt="An iTerm2 window turning glassier and changing accent color live as iglass install commands run">

<sub>Tweaking iglass live: each <code>iglass install</code> updates the open window instantly.</sub>

</div>

## Why iglass

macOS's Liquid Glass makes apps feel light and layered. iglass brings that look to your
terminal, carefully:

- **Real Liquid Glass in Ghostty** (macOS 26+): Apple's own glass material, not an imitation.
- **The closest iTerm2 allows**: transparency, blur and a palette designed to sit on top of them.
- **Linux too**: the same palettes in Ghostty on Linux, with transparency, and blur where your
  desktop provides it.
- **Four glass levels**, mirroring Apple's own options: Clear, Frosted, Tinted and Solid.
- **Follows light and dark mode** automatically, with a separate palette for each.
- **Apple's system colors** and macOS accent colors, adjusted only where contrast requires it.
- **Contrast-checked.** Every color is verified against the window *as it looks over your
  desktop*, not just against a flat background. [See the report.](docs/contrast-report.md)
- **High-contrast option** and hints for macOS Reduce Transparency / Increase Contrast (and
  GNOME's high contrast on Linux).
- **Keeps your setup.** Only the look changes: your font, keyboard shortcuts, shell and
  directories stay as they are.
- **Safe and reversible.** Everything iglass changes is backed up and undone exactly on
  uninstall.

## Ghostty: real Liquid Glass

| | Dark | Light |
|---|---|---|
| **Clear** | <img src="docs/screenshots/ghostty-clear.png" alt="iglass Clear in Ghostty, dark"> | <img src="docs/screenshots/ghostty-clear-light.png" alt="iglass Clear in Ghostty, light"> |
| **Frosted** | <img src="docs/screenshots/ghostty-frosted.png" alt="iglass Frosted in Ghostty, dark"> | <img src="docs/screenshots/ghostty-frosted-light.png" alt="iglass Frosted in Ghostty, light"> |
| **Tinted** | <img src="docs/screenshots/ghostty-tinted.png" alt="iglass Tinted in Ghostty, dark"> | <img src="docs/screenshots/ghostty-tinted-light.png" alt="iglass Tinted in Ghostty, light"> |
| **Solid** | <img src="docs/screenshots/ghostty-solid.png" alt="iglass Solid in Ghostty, dark"> | <img src="docs/screenshots/ghostty-solid-light.png" alt="iglass Solid in Ghostty, light"> |

## iTerm2

| | Dark | Light |
|---|---|---|
| **Clear** | <img src="docs/screenshots/clear.png" alt="iglass Clear in iTerm2, dark"> | <img src="docs/screenshots/clear-light.png" alt="iglass Clear in iTerm2, light"> |
| **Frosted** | <img src="docs/screenshots/frosted.png" alt="iglass Frosted in iTerm2, dark"> | <img src="docs/screenshots/frosted-light.png" alt="iglass Frosted in iTerm2, light"> |
| **Tinted** | <img src="docs/screenshots/tinted.png" alt="iglass Tinted in iTerm2, dark"> | <img src="docs/screenshots/tinted-light.png" alt="iglass Tinted in iTerm2, light"> |
| **Solid** | <img src="docs/screenshots/solid.png" alt="iglass Solid in iTerm2, dark"> | <img src="docs/screenshots/solid-light.png" alt="iglass Solid in iTerm2, light"> |

| Variant | Feels like | Transparency | Ghostty glass | Readable over |
|---|---|---|---|---|
| **Clear** | Liquid Glass *Clear* | 50% | `macos-glass-clear` | Mid-tone wallpapers (aesthetic choice) |
| **Frosted** · default¹ | Liquid Glass *Regular* | 34% | `macos-glass-regular` | Typical wallpapers |
| **Tinted** | macOS *Tinted* mode | 18% | `macos-glass-regular` | Any wallpaper |
| **Solid** | Reduce Transparency | 0% | none | Any wallpaper |

<sub>¹ On Linux desktops without blur the default is Tinted; see [Linux](#linux).</sub>

Accents: blue, purple, pink, red, orange, yellow, green, graphite (the macOS accent colors).

## Linux

iglass works with [Ghostty](https://ghostty.org) on Linux. You get the same contrast-checked
palettes, the four variants, accents and light/dark switching. Liquid Glass itself is Apple's
material, so on Linux the glass is transparency plus blur, and blur depends on your desktop:

| Desktop | Blur behind the window | Default variant | Light/dark switching |
|---|---|---|---|
| KDE Plasma | ✓ | Frosted | ✓ |
| Hyprland | ✓ (Hyprland's own blur) | Frosted | If the desktop reports it |
| GNOME and others | — | Tinted | ✓ on GNOME; elsewhere if the desktop reports it |

Clear and Frosted rely on blur to keep text readable, so on a desktop without blur iglass
installs **Tinted**, which is checked against pure black and white, and tells you why. You can
still choose any variant with `--variant`.

| | Dark | Light |
|---|---|---|
| **KDE Plasma** · Frosted | <img src="docs/screenshots/linux-kde-frosted.png" alt="iglass Frosted in Ghostty on Fedora KDE Plasma, dark"> | <img src="docs/screenshots/linux-kde-frosted-light.png" alt="iglass Frosted in Ghostty on Fedora KDE Plasma, light"> |
| **GNOME** · Tinted | <img src="docs/screenshots/linux-gnome-tinted.png" alt="iglass Tinted in Ghostty on Fedora GNOME, dark"> | <img src="docs/screenshots/linux-gnome-tinted-light.png" alt="iglass Tinted in Ghostty on Fedora GNOME, light"> |

<sub>Ghostty on Fedora 44. KDE Plasma blurs the wallpaper behind the window; GNOME shows it through.</sub>

## Install

**Requirements**
- **macOS:** macOS 15 or later, and [iTerm2](https://iterm2.com) 3.5+ or
  [Ghostty](https://ghostty.org) 1.0+. Real Liquid Glass needs macOS 26+ and a recent Ghostty.
- **Linux:** [Ghostty](https://ghostty.org/download) 1.0+ with the `ghostty` command on your
  PATH, plus `bash`, `curl` and `jq` (`sudo apt install jq`, `sudo dnf install jq`,
  `sudo pacman -S jq`).

With Homebrew (macOS or Linux):

```sh
brew install vukkt/tap/iglass
iglass install
```

Or with the install script, which downloads the latest release (puts `iglass` in `~/.local/bin`):

```sh
curl -fsSL https://raw.githubusercontent.com/vukkt/iglass/main/install.sh | bash
iglass install
```

Or from source:

```sh
git clone https://github.com/vukkt/iglass.git
cd iglass && ./install.sh --local
iglass install
```

`iglass install` sets up the terminal you run it in (on Linux, always Ghostty). Use
`--terminal iterm2`, `ghostty` or `all` to choose. In iTerm2, open a window with
`iglass preview` or pick **Profiles › iglass Frosted**. In Ghostty, quit and reopen it
(Ghostty reads transparency only at launch).

<details>
<summary>Without the CLI</summary>

**iTerm2:** copy [`themes/iglass.json`](themes/iglass.json) into
`~/Library/Application Support/iTerm2/DynamicProfiles/`. iTerm2 picks it up immediately.
Plain color presets are in [`themes/`](themes) too (iTerm2 › Settings › Profiles › Colors ›
Color Presets › Import), but they carry colors only, not the glass settings.

**Ghostty:** copy the files in [`themes/ghostty/themes`](themes/ghostty/themes) to
`~/.config/ghostty/themes/`, then add to your Ghostty config:

```
theme = light:iglass-frosted-light,dark:iglass-frosted-dark
```

(or `theme = iglass-frosted-dark` to stay dark all the time).

These files use macOS's real Liquid Glass. On Linux, use the CLI, or make your own with
`iglass export --terminal ghostty --glass blur --dir ./iglass-ghostty`.

</details>

## Usage

```sh
iglass install                          # all four variants, blue accent
iglass install --accent purple          # pick an accent
iglass install --contrast high          # stronger colors
iglass install --appearance dark        # always dark, even when macOS or your desktop is light
iglass install --terminal all           # iTerm2 and Ghostty
iglass install --app-settings           # iTerm2 (macOS): native title bar + roomier padding (restarts iTerm2)
iglass install --variant tinted --default   # iTerm2 (macOS): make a variant your default profile

iglass preview --variant clear          # open a window to try a variant
iglass list                             # variants and accents
iglass status                           # what's installed
iglass doctor                           # check for problems (changes nothing)
iglass uninstall                        # remove everything, restore settings
```

### Fine-tuning

```sh
iglass install --opacity 0.8 --blur 18      # adds an "iglass Custom" profile / theme
iglass install --cursor box                  # bar (default), box, underline, keep
iglass install --window no-titlebar          # native (default), no-titlebar, keep
iglass install --font sf-mono                # keep (default), sf-mono, or "PostScriptName 14"
iglass install --glass blur                  # Ghostty on macOS: classic blur instead of real glass
iglass export --accent green > my.json       # print the iTerm2 profiles file instead
```

Opacity below the readable minimum (0.66) asks for `--force`.

### What iglass changes in Ghostty

- Theme files in `~/.config/ghostty/themes/iglass-*`, one per variant and appearance, with the
  colors, opacity and glass.
- `~/.config/ghostty/iglass.ghostty`: which theme to use, padding and cursor.
- Two lines, after a blank line, at the end of your Ghostty config (the one Ghostty loads
  last): a comment and an optional `config-file` include. Your config is backed up first,
  symlinked dotfiles stay symlinks, and `iglass uninstall` restores the file exactly.
- iglass's own record of what it changed, and the backup of your config, live in
  `~/Library/Application Support/iglass` on macOS and `~/.local/state/iglass` on Linux.

### App-wide settings (iTerm2)

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

One contrast-checked palette drives both terminals:

1. [`design/palettes.json`](design/palettes.json) holds Apple's system colors, the variants and
   the contrast targets.
2. [`tools/build_palettes.py`](tools/build_palettes.py) blends each window background over
   black, white and grey desktops at each variant's transparency, checks every color against
   the worst case, and nudges lightness (in OKLCH, keeping hue) only where a color falls short.
3. The result ships as [`data/palette.json`](data/palette.json), and every decision is listed
   in the [contrast report](docs/contrast-report.md).

For **iTerm2**, iglass installs a
[dynamic profile](https://iterm2.com/documentation-dynamic-profiles.html). A dynamic profile
inherits everything it doesn't set from your default profile, so iglass sets every color and
every setting iTerm2 keeps separately for light and dark mode (a test enforces this), and
nothing about how you work. Files are validated with Apple's parser first, because one
unreadable file stops iTerm2 from loading *any* dynamic profile.

For **Ghostty**, iglass writes theme files and checks them with Ghostty's own validator before
anything touches your config. It asks Ghostty whether it supports `macos-glass` rather than
guessing from version numbers.

The CLI is plain bash plus the `jq`, `plutil` and `defaults` that ship with macOS, so there is
nothing else to install on a Mac. On Linux it needs `jq`, and uses fontconfig to check fonts.
More detail, including what was verified in iTerm2's and Ghostty's behavior:
[docs/research-notes.md](docs/research-notes.md).

## FAQ

### Is this real Liquid Glass?

**In Ghostty, yes**, on macOS 26 and later: iglass uses Ghostty's `macos-glass-regular` and
`macos-glass-clear`, which are Apple's own glass material.

**In iTerm2, no**, and no theme can change that. iTerm2 hasn't shipped Liquid Glass for
terminal windows: a [pull request adding it](https://github.com/gnachman/iTerm2/pull/767) was
closed because glass breaks window resizing in a terminal. iglass gets as close as iTerm2
allows with transparency, blur and a matching palette, and will use real glass if iTerm2 adds it.

### Is it Liquid Glass on Linux?

No. Liquid Glass is Apple's material and only exists on macOS. On Linux, iglass uses the same
palettes with transparency and blur, so it looks glassy and stays readable. Blur depends on
your desktop (see [Linux](#linux)).

### Isn't glass behind text against Apple's own advice?

Partly. Apple reserves glass for controls and navigation and keeps content clear. Terminal text
*is* content, which is why Frosted is the default (Tinted on Linux desktops without blur),
Tinted and Solid exist, and every variant is contrast-checked. Choose the level that suits you; Tinted is the most Apple-like for long work.

### Can iglass stay dark when my system switches to light?

Yes: `iglass install --appearance dark` keeps iglass dark (or `light` keeps it light) while
macOS or your Linux desktop keeps switching. `--appearance auto`, the default, follows it again.
Like the other options, run it with the rest of your choices, e.g.
`iglass install --variant clear --accent pink --appearance dark`.

### Ghostty didn't change.

Quit and reopen Ghostty: it reads transparency only at launch. If it still looks the same, run
`iglass doctor`; another config file loading after yours can override iglass.

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
iglass uninstall            # removes iglass from every terminal; asks to restore iTerm2 settings
brew uninstall iglass       # or: curl -fsSL …/install.sh | bash -s -- --uninstall
```

## Development

```sh
make palettes          # rebuild colors after editing design/palettes.json
make themes            # rebuild the prebuilt themes/ files
make check             # shellcheck, generated-file check, palette tests, bats suite
tools/screenshots.sh   # README screenshots over a generated backdrop (needs Screen Recording)
tools/record-gif.sh    # docs/demo.gif (needs ffmpeg)
osascript -l JavaScript tools/social-card.js BACKDROP.png SHOT.png docs/social-preview.png
```

Tests run in a sandbox with stand-ins for iTerm2, Ghostty and system commands, so they never
touch your real settings. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

iglass is an independent project, not affiliated with or endorsed by Apple Inc., iTerm2 or
Ghostty. Liquid Glass, macOS and SF Mono are trademarks of Apple Inc.

MIT · built by [@vukkt](https://github.com/vukkt) · [sponsor](https://github.com/sponsors/vukkt)
