# Research notes

What we verified before writing code, and why iglass is built the way it is.
Verified on macOS 27.0.1 with iTerm2 3.7.4 and Ghostty 1.3.1, and on Linux with Ghostty 1.3.1
on Fedora 44 (KDE Plasma and GNOME, aarch64) and Ubuntu 24.04 (October 2026).

## Can iTerm2 use real Liquid Glass?

No, not from a theme. A pull request that added a per-profile "Blur Style → Liquid Glass" option
([gnachman/iTerm2#767](https://github.com/gnachman/iTerm2/pull/767)) was closed without merging.
The maintainer's reason: hosting `NSGlassEffectView` in a terminal window forces Auto Layout,
which breaks window resizing. iTerm2 3.7.4 contains internal glass-view code but exposes no
setting for it (there is no `Blur Style` key in the shipped binary).

There is a second reason not to depend on it today: on macOS 27, an `NSGlassEffectView` tinted
with a dark, near-opaque color renders as a solid fill
([manaflow-ai/cmux#5860](https://github.com/manaflow-ai/cmux/issues/5860)), and dark terminal
backgrounds are exactly that.

iglass therefore builds the look from what iTerm2 supports reliably: window transparency,
background blur, and a palette tuned to stay readable on top of them.

## Profile keys

Confirmed against `sources/Settings/Profiles/ITAddressBookMgr.h` and real preferences.

| Key | Type | Notes |
|---|---|---|
| `Transparency` | real 0–1 | 0 = opaque. iglass's `--opacity` is `1 - Transparency`. |
| `Blur`, `Blur Radius` | bool, real 0–64 | iTerm2 warns above 26 (slow on some machines). |
| `Initial Use Transparency` | bool | New sessions start transparent. |
| `Only The Default BG Color Uses Transparency` | bool | Keeps colored backgrounds (vim, htop) solid. |
| `Minimum Contrast` | real 0–1 | iTerm2 raises text contrast at render time. |
| `Use Separate Colors for Light and Dark Mode` | bool | Enables the `… (Light)` / `… (Dark)` color keys. |
| `Cursor Type` | int | 0 underline, 1 vertical bar, 2 box (`iTermCursor.h`). |
| `Cursor Smooth Slide`, `Cursor Smooth Blink`, `Cursor Shadow` | bool | |
| `Window Type` | int | 0 normal, 12 no title bar, 13 compact. The Minimal theme turns normal into compact. |

Colors are dictionaries of `Red/Green/Blue/Alpha Component` (0–1) plus `Color Space`
(`sRGB` or `P3`). iglass uses `sRGB` so Apple's published system-color values carry over exactly.

## App-wide (global) settings

These live in `com.googlecode.iterm2` and cannot be set by a profile
(`sources/Settings/iTermPreferences.m`):

| Key | Default | iglass `--app-settings` |
|---|---|---|
| `TabStyleWithAutomaticOption` | 0 | 4 (Automatic: macOS draws the title bar and tabs) |
| `TerminalMargin` (side padding) | 5 | more generous padding |
| `TerminalVMargin` (top/bottom) | 2 | more generous padding |

iTerm2 writes its preferences back when it quits, so global values must be changed while it is
not running. If `LoadPrefsFromCustomFolder` is set, iTerm2 reads preferences from a different
place and iglass refuses to write global settings.

## Dynamic profiles

- JSON files in `~/Library/Application Support/iTerm2/DynamicProfiles/`, reloaded live.
- Each profile needs a `Name` and a unique `Guid`. iglass uses fixed GUIDs, so reinstalling
  updates profiles in place instead of duplicating them.
- Keys a profile leaves out are inherited from the user's default profile, so iglass sets only
  appearance keys. Keyboard maps, shell, working directory and font stay the user's own.
- **One malformed file in the folder stops iTerm2 from loading every dynamic profile.**
  iglass writes atomically (temporary file outside the folder → validate → rename), and
  `iglass doctor` checks every file in the folder.
- `plutil -lint` does **not** accept JSON. The validator is `plutil -convert xml1 -o /dev/null`,
  which runs Apple's parser on JSON, XML and binary plists alike, and also rejects JSON `null`,
  which a property list cannot hold.

### Light and dark copies of settings

iTerm2 keeps 45 profile keys separately for light and dark mode (`… (Light)`, `… (Dark)`),
listed in `iTermProfilePreferences.m`. Besides the 31 colors, these include behavior keys such
as `Minimum Contrast`, `Faint Text Alpha`, `Brighten Bold Text`, `Harmonize 256 Colors` and the
`Use … Color` switches. Any of them a profile leaves out is inherited from the user's default
profile, in that mode only. iglass sets 44 of them in all three forms; the test suite fails if
one goes missing. The 45th, `HDR Cursor Brightness`, has no effect because iglass sets
`HDR Cursor` to false.

## Restarting iTerm2 safely

The installer usually runs *inside* iTerm2, so it cannot quit iTerm2 and keep running. iglass
hands the apply step to launchd with `launchctl submit`. The job's parent is launchd (`ppid=1`),
not iTerm2. launchd restarts submitted jobs that exit with failure, so the helper always exits 0
and removes its own label when done.

## Apple's Liquid Glass guidance

From [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass):

- *"This material forms a distinct functional layer for controls and navigation elements … to
  help bring focus to the underlying content."* Terminal text is content, so translucency
  behind it is a stylistic choice, not Apple's pattern. That is why Frosted (not Clear) is the
  default, Tinted and Solid exist, and every variant is contrast-checked.
- *"Define a custom color with light and dark variants, and an increased contrast option for
  each variant."* → separate light/dark palettes and `--contrast high`.
- *"Test … with accessibility settings that reduce transparency."* → the Solid variant, plus
  hints when Reduce Transparency or Increase Contrast is on.
- *"Give content room to breathe … larger row height and padding."* → `--app-settings` padding.

## Contrast model

A translucent window has no single background: it is the window color blended over whatever
the desktop shows. The palette build checks colors against that blend, in three tiers:

- **Tinted, Solid:** over pure black and pure white desktops. Readable over anything.
- **Frosted:** over dark (`#333`) and light (`#CCC`) grey, standing in for typical blurred
  wallpapers. At 34% transparency, no white text can reach 7:1 over a pure white desktop, so a
  strict guarantee would mean washing every color out to pastel.
- **Clear:** over mid-grey only. An aesthetic choice, labeled as such.

The high-contrast palette starts from the finished standard colors, so no color can end up
weaker than its standard counterpart (a test checks this).

## Ghostty

Ghostty's `background-blur` accepts `macos-glass-regular` and `macos-glass-clear` on macOS 26+,
which host Apple's real glass material. On macOS 27, a glass view tinted with a near-opaque
dark color was reported to render as a solid fill in another Ghostty-based app
([manaflow-ai/cmux#5860](https://github.com/manaflow-ai/cmux/issues/5860)). Ghostty 1.3.1 itself
renders correctly here at every iglass opacity, including 0.90 with a dark background
(checked over a backdrop before shipping).

- **Themes may set any option** (except `theme` and `config-file`), so each iglass theme
  carries its variant's opacity and glass alongside the colors.
- **Config files** load in this order, later winning: `$XDG_CONFIG_HOME/ghostty/config.ghostty`,
  `…/config`, then the same two names under `~/Library/Application Support/com.mitchellh.ghostty`.
  The file name `config.ghostty` arrived in Ghostty 1.2.3. iglass adds its include to the
  last existing file.
- **`config-file` includes** are processed after the rest of the file that names them, so the
  include overrides a `theme` set anywhere in the same file. A `?` prefix makes the include
  optional, and quoted paths with spaces work.
- **`+validate-config`** also loads the user's own config files, and silently fails when given
  `--config-default-files=false`. iglass validates with `HOME` and `XDG_CONFIG_HOME` pointed at
  a scratch folder holding only its files.
- **`background-opacity` is read only at launch** on macOS; colors can be reloaded live.
- Ghostty prints "failed to launch the requested command" for commands that exit within about
  a second, which matters when scripting it (the screenshot tool keeps its command running).

## Fonts

SF Mono ships inside `Terminal.app/Contents/Resources/Fonts/` but is not installed system-wide
by default, and Apple's license does not allow redistributing it. iglass keeps the user's font by
default. Many users rely on Nerd Fonts for prompt icons, and replacing the font would break those.
`--font` is opt-in. Font availability is checked through `NSFont` with JavaScript for Automation.

For Ghostty, `--font` takes the same PostScript name and iglass looks up the family name
Ghostty needs through `NSFont`, or through fontconfig (`fc-list :postscriptname=NAME family`)
on Linux.

## Linux

- **Ghostty on Linux reads only `$XDG_CONFIG_HOME/ghostty`** (`config.ghostty`, then `config`);
  there is no Application Support location. The `ghostty` command reports its version on the
  first line of `ghostty --version` (distribution builds append a suffix, e.g. `1.3.1-4.fc44`).
- **Blur depends on the desktop.** KDE Plasma's KWin blurs behind Ghostty when
  `background-blur` is set (verified, Wayland). GNOME doesn't blur behind app windows, so the
  background shows through sharply (verified). Clear and Frosted are contrast-checked assuming
  blur, so on desktops other than KDE Plasma and Hyprland (which blurs translucent windows
  itself) iglass defaults to Tinted, which is checked against pure black and white.
- **Light/dark switching works live** on both KDE Plasma (color scheme) and GNOME
  (`color-scheme` setting): Ghostty follows the desktop through `theme = light:…,dark:…`.
- **`gtk-titlebar = false`** hides the title bar on Linux; Ghostty's validator accepts it.
- **`awk` differs between systems.** Fedora and Arch use GNU awk, where `include` is a reserved
  word; Ubuntu uses mawk and macOS BSD awk, where it isn't. Using it as a variable name made
  uninstall write an empty config under gawk. CI now runs with gawk, and iglass never rewrites
  a config when the awk step fails.
- **Tool flags differ.** GNU `stat -f` means "file system status" and succeeds with unrelated
  output, so iglass picks `stat -f %Lp` or `stat -c %a` by OS rather than trying one then the
  other. Linux `pgrep` doesn't hide its own ancestors, and its `-a` means "print the command
  line". `lib/platform.sh` holds these differences.
- **Ghostty needs OpenGL 4.3.** In a virtual machine whose GPU offers less, Ghostty can't create
  a GL context; `LIBGL_ALWAYS_SOFTWARE=1 ghostty` (Mesa's software renderer) works for testing.
- Ghostty isn't distributed on Flathub. Linux installs (distribution packages, the Snap, Nix,
  source builds) provide a `ghostty` command that reads `~/.config/ghostty`.

## Screenshots

Translucent windows show whatever is behind them, including other windows' text. Screenshots
and the demo GIF are taken over a generated backdrop (`tools/backdrop.py`) shown in a temporary,
opaque iTerm2 window, so they are reproducible and never capture anything personal. The Linux
screenshots were taken in Fedora virtual machines, capturing only the VM's window. In iTerm2
profiles, `Blend: 1` shows a background image at full strength and `0` hides it (verified).
