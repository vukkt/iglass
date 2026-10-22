<div align="center">

# iglass

**Liquid Glass for your terminal.** A theme for iTerm2, Ghostty, kitty and Warp, on macOS and Linux.
Translucent, built from Apple's system colors, and contrast-checked so it stays readable.

[![CI](https://github.com/vukkt/iglass/actions/workflows/ci.yml/badge.svg)](https://github.com/vukkt/iglass/actions/workflows/ci.yml)
![Platforms: macOS 15+ and Linux](https://img.shields.io/badge/platforms-macOS%2015%2B%20%C2%B7%20Linux-black)
![Terminals: iTerm2, Ghostty, kitty and Warp](https://img.shields.io/badge/terminals-iTerm2%20%C2%B7%20Ghostty%20%C2%B7%20kitty%20%C2%B7%20Warp-black)
![License: MIT](https://img.shields.io/badge/license-MIT-black)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-db61a2?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/vukkt)

**[Website](https://vukkt.github.io/iglass/)** · [Install](#install) · [Usage](#usage) · [kitty](#kitty) · [Warp](#warp) · [Linux](#linux) · [FAQ](#faq)

<img src="docs/demo.gif" width="760" alt="An iTerm2 window turning glassier and changing accent color live as iglass install commands run">

<sub>Tweaking iglass live: each <code>iglass install</code> updates the open window instantly.</sub>

</div>

## Quick start

```sh
brew install vukkt/tap/iglass   # macOS or Linux; or use the install script below
iglass install                  # sets up the terminal you run it in
```

`iglass uninstall` undoes everything. More options: [Install](#install) and [Usage](#usage).

## Why iglass

macOS's Liquid Glass makes apps feel light and layered. iglass brings that look to your
terminal, carefully:

- **Real Liquid Glass in Ghostty** (macOS 26+): Apple's own glass material, not an imitation.
- **The closest iTerm2 allows**: transparency, blur and a palette designed to sit on top of them.
- **kitty too**: kitty's own blur on macOS (and on Linux desktops that support it), with a title
  bar that's part of the glass.
- **Warp too**: iglass's colors as Warp themes that follow light and dark mode, and the glass
  through Warp's own window opacity and blur. Warp applies it the moment you install.
- **Linux too**: the same palettes in Ghostty, kitty and Warp on Linux, with transparency, and
  blur where your desktop provides it.
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

## kitty

kitty blurs behind its own windows on macOS, and on Linux where the desktop supports it (KDE
Plasma, Hyprland, niri 26.04+, GNOME 51+). iglass gives it the same palettes, glass levels and accents, a title bar that's
part of the glass, and colors that switch with light and dark mode (kitty 0.38+).

| | Dark | Light |
|---|---|---|
| **Clear** | <img src="docs/screenshots/kitty-clear.png" alt="iglass Clear in kitty, dark"> | <img src="docs/screenshots/kitty-clear-light.png" alt="iglass Clear in kitty, light"> |
| **Frosted** | <img src="docs/screenshots/kitty-frosted.png" alt="iglass Frosted in kitty, dark"> | <img src="docs/screenshots/kitty-frosted-light.png" alt="iglass Frosted in kitty, light"> |
| **Tinted** | <img src="docs/screenshots/kitty-tinted.png" alt="iglass Tinted in kitty, dark"> | <img src="docs/screenshots/kitty-tinted-light.png" alt="iglass Tinted in kitty, light"> |
| **Solid** | <img src="docs/screenshots/kitty-solid.png" alt="iglass Solid in kitty, dark"> | <img src="docs/screenshots/kitty-solid-light.png" alt="iglass Solid in kitty, light"> |

<sub>kitty 0.49 on macOS.</sub>

## Warp

Warp has its own theme format and a settings file it watches, so iglass installs two Warp themes
(**iglass Dark** and **iglass Light**, switched with light and dark mode by Warp itself) and sets
Warp's window opacity and blur to the variant you pick. Warp applies it right away, no restart.
Everything else in your Warp settings stays as it is, and `iglass uninstall` puts back what was
there before.

```sh
iglass install --terminal warp                    # Frosted: 66% opaque, blur 24
iglass install --terminal warp --variant clear    # the most see-through: 50% opaque
```

On macOS Warp blurs behind its windows. On Linux Warp has no blur setting, so the glass is
transparency, and blur where the desktop adds it (Hyprland, or niri with a window rule). Warp
reads `settings.toml` from its April 2026 releases on; `iglass doctor` tells you if yours is older.

<details>
<summary><b>iTerm2 gallery</b> (all four variants, light and dark)</summary>

| | Dark | Light |
|---|---|---|
| **Clear** | <img src="docs/screenshots/clear.png" alt="iglass Clear in iTerm2, dark"> | <img src="docs/screenshots/clear-light.png" alt="iglass Clear in iTerm2, light"> |
| **Frosted** | <img src="docs/screenshots/frosted.png" alt="iglass Frosted in iTerm2, dark"> | <img src="docs/screenshots/frosted-light.png" alt="iglass Frosted in iTerm2, light"> |
| **Tinted** | <img src="docs/screenshots/tinted.png" alt="iglass Tinted in iTerm2, dark"> | <img src="docs/screenshots/tinted-light.png" alt="iglass Tinted in iTerm2, light"> |
| **Solid** | <img src="docs/screenshots/solid.png" alt="iglass Solid in iTerm2, dark"> | <img src="docs/screenshots/solid-light.png" alt="iglass Solid in iTerm2, light"> |

</details>

| Variant | Feels like | Transparency | Ghostty glass | Warp opacity · blur | Readable over |
|---|---|---|---|---|---|
| **Clear** | Liquid Glass *Clear* | 50% | `macos-glass-clear` | 50 · 12 | Mid-tone wallpapers (aesthetic choice) |
| **Frosted** · default¹ | Liquid Glass *Regular* | 34% | `macos-glass-regular` | 66 · 24 | Typical wallpapers |
| **Tinted** | macOS *Tinted* mode | 18% | `macos-glass-regular` | 82 · 26 | Any wallpaper |
| **Solid** | Reduce Transparency | 0% | none | 100 · none | Any wallpaper |

<sub>¹ On Linux desktops without blur the default is Tinted; see [Linux](#linux).</sub>

Accents: blue, purple, pink, red, orange, yellow, green, graphite (the macOS accent colors).

## Linux

iglass works with [Ghostty](https://ghostty.org), [kitty](https://sw.kovidgoyal.net/kitty/) and
[Warp](https://www.warp.dev) on Linux. You get the same contrast-checked
palettes, the four variants, accents and light/dark switching. Liquid Glass itself is Apple's
material, so on Linux the glass is transparency plus blur, and blur depends on your desktop:

| Desktop | Blur behind kitty | Blur behind Ghostty | Blur behind Warp | Light/dark switching |
|---|---|---|---|---|
| KDE Plasma | ✓ | ✓ | — | ✓ |
| Hyprland | ✓ (Hyprland's own blur) | ✓ (Hyprland's own blur) | ✓ (Hyprland's own blur) | If the desktop reports it |
| niri 26.04+ | ✓ (kitty 0.46.2+) | Ghostty 1.4+, or now with a niri window rule | With a niri window rule | If the desktop reports it |
| GNOME 51+ | ✓ (kitty 0.46.2+) | Ghostty 1.4+ | — | ✓ |
| GNOME 50 and earlier, others | — | — | — | ✓ on GNOME; elsewhere if the desktop reports it |

iglass recognizes the desktop and its version. Where it blurs, the default is **Frosted**. Clear
and Frosted rely on blur to keep text readable, so where it doesn't, iglass installs **Tinted**,
which is checked against pure black and white, and tells you why. On niri it also prints the
window rule that adds blur behind a terminal that doesn't ask for it yet. You can still choose
any variant with `--variant`.

iglass also recognizes your distribution: Arch-based ones (Arch, Garuda, CachyOS, Manjaro,
EndeavourOS), Debian and Ubuntu, Fedora, and openSUSE get install hints for their own package
manager. On Garuda or any Arch-based system:

```sh
sudo pacman -S --needed jq kitty     # or ghostty
curl -fsSL https://raw.githubusercontent.com/vukkt/iglass/main/install.sh | bash
iglass install
```

| | Dark | Light |
|---|---|---|
| **KDE Plasma** · Frosted | <img src="docs/screenshots/linux-kde-frosted.png" alt="iglass Frosted in Ghostty on Fedora KDE Plasma, dark"> | <img src="docs/screenshots/linux-kde-frosted-light.png" alt="iglass Frosted in Ghostty on Fedora KDE Plasma, light"> |
| **GNOME** · Tinted | <img src="docs/screenshots/linux-gnome-tinted.png" alt="iglass Tinted in Ghostty on Fedora GNOME, dark"> | <img src="docs/screenshots/linux-gnome-tinted-light.png" alt="iglass Tinted in Ghostty on Fedora GNOME, light"> |

<sub>Ghostty on Fedora 44. KDE Plasma blurs the wallpaper behind the window; GNOME shows it through.</sub>

## Install

**Requirements**
- **macOS:** macOS 15 or later, and [iTerm2](https://iterm2.com) 3.5+,
  [Ghostty](https://ghostty.org) 1.0+, [kitty](https://sw.kovidgoyal.net/kitty/) 0.38+ or
  [Warp](https://www.warp.dev) (April 2026 or later). Real Liquid Glass needs macOS 26+ and a
  recent Ghostty.
- **Linux:** [Ghostty](https://ghostty.org/download) 1.0+,
  [kitty](https://sw.kovidgoyal.net/kitty/binary/) 0.38+ or [Warp](https://www.warp.dev/download)
  with its command on your PATH, plus `bash`, `curl` and `jq` (`sudo apt install jq`,
  `sudo dnf install jq`, `sudo pacman -S jq`).
- Earlier kitty versions work too, without switching colors with light and dark mode.

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

`iglass install` sets up the terminal you run it in. Use `--terminal iterm2`, `ghostty`, `kitty`,
`warp` or `all` to choose. In iTerm2, open a window with `iglass preview` or pick **Profiles ›
iglass Frosted**. In Ghostty and kitty, quit and reopen them (they read transparency only at
launch). Warp changes right away.

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

**kitty:** copy the files in [`themes/kitty`](themes/kitty) to your kitty config folder (usually
`~/.config/kitty`), then add `include iglass.conf` to the end of your `kitty.conf`. If you made
light/dark themes with `kitten themes`, these replace them, so keep a copy.

**Warp:** copy `iglass-dark.yaml` and `iglass-light.yaml` from [`themes/warp`](themes/warp) to
`~/.warp/themes/` (Linux: `~/.local/share/warp-terminal/themes/`), then add the lines in
[`iglass-settings.toml`](themes/warp/iglass-settings.toml) to Warp's `settings.toml`, replacing any
settings with the same names. Or just pick **iglass Dark** or **iglass Light** under Settings ›
Appearance › Themes, and set the window opacity there.

</details>

## Usage

```sh
iglass install                          # all four variants, blue accent
iglass install --accent purple          # pick an accent
iglass install --contrast high          # stronger colors
iglass install --appearance dark        # always dark, even when macOS or your desktop is light
iglass install --terminal warp          # pick the terminal (default: the one you're in)
iglass install --terminal all           # every supported terminal you have installed
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

### What iglass changes in kitty

In the folder kitty reads its configuration from (chosen exactly the way kitty chooses it,
usually `~/.config/kitty`):

- `iglass.conf`: opacity, blur, padding and cursor.
- `dark-theme.auto.conf`, `light-theme.auto.conf` and `no-preference-theme.auto.conf`: the
  colors kitty switches between with light and dark mode. If you already have your own (from
  `kitten themes`), iglass sets them aside and puts them back on uninstall.
- Two lines at the end of `kitty.conf`: a comment and `include iglass.conf`. Like Ghostty's,
  backed up first and restored exactly by `iglass uninstall`.

### What iglass changes in Warp

- `iglass-dark.yaml` and `iglass-light.yaml` in Warp's themes folder (`~/.warp/themes` on macOS,
  `~/.local/share/warp-terminal/themes` on Linux): the colors and accent.
- A few settings in Warp's `settings.toml` (`~/.warp/settings.toml` on macOS,
  `~/.config/warp-terminal/settings.toml` on Linux): the theme and following light and dark
  mode (`[appearance.themes]`), window opacity and blur (`[appearance.window]`), the cursor
  unless you pass `--cursor keep`, and the font with `--font`. Every other line, comment and
  setting stays as it was.
- `iglass uninstall` puts back the values you had, removes what iglass added, and leaves alone
  anything you changed in Warp since. If nothing else changed, the file comes back byte for
  byte. iglass checks every setting against the schema Warp ships before writing anything.
- If you use Warp's Settings Sync, Warp syncs these settings to your other computers, like any
  change you make on its settings page.

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

One contrast-checked palette drives every terminal:

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

For **kitty**, which has no validator command, iglass loads every generated file with kitty's own
config parser (the one kitty runs at startup) before anything touches your config.

For **Warp**, iglass checks each setting it writes against the settings schema that ships inside
Warp, so a renamed setting stops the install instead of breaking your settings. It edits
`settings.toml` line by line, and CI validates the result against the schema of Warp's latest
release.

The CLI is plain bash plus the `jq`, `plutil` and `defaults` that ship with macOS, so there is
nothing else to install on a Mac. On Linux it needs `jq`, and uses fontconfig to check fonts.
More detail, including what was verified in each terminal's behavior:
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

### Is it Liquid Glass in kitty or Warp?

No: neither has access to Apple's glass material, so iglass uses their own transparency and
blur. In kitty, with the matching title bar, it looks and feels like glass. For the real
material on macOS, use Ghostty.

### Warp didn't change.

Run `iglass doctor`. Warp reads `settings.toml` from its April 2026 releases on; doctor says if
yours is older, and shows any iglass setting you've since changed on Warp's settings page.

### Isn't glass behind text against Apple's own advice?

Partly. Apple reserves glass for controls and navigation and keeps content clear. Terminal text
*is* content, which is why Frosted is the default (Tinted on Linux desktops without blur),
Tinted and Solid exist, and every variant is contrast-checked. Choose the level that suits you;
Tinted is the most Apple-like for long work.

### Can iglass stay dark when my system switches to light?

Yes: `iglass install --appearance dark` keeps iglass dark (or `light` keeps it light) while
macOS or your Linux desktop keeps switching. `--appearance auto`, the default, follows it again.
Like the other options, run it with the rest of your choices, e.g.
`iglass install --variant clear --accent pink --appearance dark`.

### Ghostty or kitty didn't change.

Quit and reopen it: both read transparency only at launch. If it still looks the same, run
`iglass doctor`. In Ghostty, a config file loading after yours can override iglass; in kitty,
settings after iglass's `include` line in `kitty.conf` can.

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

The website ([vukkt.github.io/iglass](https://vukkt.github.io/iglass/)) is `site/index.html`, published
by the Website workflow with images taken from `docs/screenshots` at build time.

Tests run in a sandbox with stand-ins for iTerm2, Ghostty, kitty, Warp and system commands, so
they never touch your real settings. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

iglass is an independent project, not affiliated with or endorsed by Apple Inc., iTerm2, Ghostty,
kitty or Warp. Liquid Glass, macOS and SF Mono are trademarks of Apple Inc.

MIT · built by [@vukkt](https://github.com/vukkt) · [sponsor](https://github.com/sponsors/vukkt)
