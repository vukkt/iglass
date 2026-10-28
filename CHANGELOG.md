# Changelog

All notable changes to iglass. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [1.6.1] - 2026-10-28

### Fixed
- **Blur on KDE Plasma and Hyprland after this year's protocol change.** KDE Plasma 6.7 replaced
  KDE's own blur protocol with the shared `ext-background-effect-v1`, and Ghostty 1.4 (released
  2026-10-27) now uses only the new one. iglass assumed KDE Plasma always blurs behind Ghostty
  and kitty; it now reads the Plasma version (`plasmashell --version`) and knows that Plasma
  6.7+ blurs Ghostty 1.4+ and kitty 0.46.2+, and earlier Plasma blurs kitty and Ghostty before
  1.4. Where the combination doesn't blur, iglass picks Tinted and says why, as on other
  desktops.
- On Hyprland, GTK 4.24 stopped blur behind GTK apps that don't ask for it, which includes
  Ghostty before 1.4. iglass reads Ghostty's GTK version and picks Tinted for that combination.

## [1.6.0] - 2026-10-22

### Added
- **Warp support**, on macOS and Linux, requested by a Product Hunt commenter: iglass's colors as
  two Warp themes (iglass Dark and iglass Light) that Warp switches with light and dark mode,
  and the glass through Warp's window opacity and blur (Clear 50%, Frosted 66%, Tinted 82%,
  Solid opaque; blur on macOS). Accents, `--contrast`, `--appearance`, `--cursor`, `--font`,
  `--opacity` and `--blur` all apply. Warp picks the change up immediately, without a restart.
- iglass edits Warp's `settings.toml` line by line and leaves every other line, comment and
  setting as it was. Uninstall restores the values you had, keeps anything you changed in Warp
  since, and restores the file byte for byte when nothing else changed. Settings written in a
  form iglass doesn't edit (dotted keys, inline tables) stop the install instead of being
  duplicated.
- Before writing, iglass checks every setting against the settings schema that ships inside
  the installed Warp, and `doctor` reports a Warp too old to read `settings.toml`, settings
  changed on Warp's settings page, and whether the Linux desktop blurs behind Warp (Hyprland
  does; niri can with the window rule iglass prints; KDE Plasma and GNOME don't).
- `--terminal warp`, and Warp in `--terminal all`, `doctor`, `status`, `uninstall` and
  `export --dir`. iglass recognizes it runs inside Warp (`TERM_PROGRAM=WarpTerminal`).
- Prebuilt Warp files in `themes/warp/`.
- CI downloads Warp's latest Linux release and validates what iglass writes, on Linux and
  macOS, against that release's settings schema, then checks the byte-for-byte uninstall.

### Fixed
- The "blur above 26 can make iTerm2 slow" warning appeared when installing only for other
  terminals; it now shows only when iTerm2 is among them.
- Test suites: checks written as `[[ … ]]` in the middle of a test didn't fail the test under
  macOS's bash 3.2, so some assertions only ran on Linux CI. They now fail everywhere.

## [1.5.0] - 2026-10-19

### Added
- **niri and GNOME 51 blur.** niri 26.04+ and GNOME 51+ blur behind apps that ask for it, which
  kitty does from 0.46.2 and Ghostty from 1.4. iglass recognizes the desktop and its version and
  picks Frosted where the glass is blurred, Tinted where it isn't. On niri, with a terminal that
  doesn't ask yet, it prints the window rule that adds blur.
- **Distributions are recognized**: Arch-based systems (Garuda, CachyOS, Manjaro, EndeavourOS),
  Debian and Ubuntu, Fedora, and openSUSE get install hints for their own package manager, in
  iglass and in the install script.
- `doctor` shows the desktop and its version next to the distribution, and says per terminal
  whether the desktop blurs behind it.

### Fixed
- On Ubuntu (`XDG_CURRENT_DESKTOP=ubuntu:GNOME`) messages named the desktop "ubuntu"; they now say
  GNOME, and KDE is called KDE Plasma.

## [1.4.0] - 2026-10-19

### Added
- **kitty support**, on macOS and Linux: the same palettes, glass levels, accents and
  `--appearance`, with kitty's own blur (on macOS, and on Linux desktops that support it) and a
  title bar that's part of the glass. Colors switch with light and dark mode through kitty's
  theme files (kitty 0.38+); a user's own theme files are set aside and restored on uninstall.
- iglass finds kitty's config the way kitty does (`KITTY_CONFIG_DIRECTORY`, `XDG_CONFIG_HOME`,
  `~/.config`, `~/Library/Preferences`, `XDG_CONFIG_DIRS`), validates every file with kitty's own
  config parser before changing anything, and restores `kitty.conf` byte for byte on uninstall.
- `--terminal kitty`; `--terminal all` now covers every supported terminal you have installed and
  skips the others. `doctor`, `status`, `preview` and `export --dir` cover kitty.
- Prebuilt kitty files in `themes/kitty/`, and kitty screenshots.
- CI checks the generated files with the real kitty on macOS and Linux, and runs an end-to-end
  install and uninstall against kitty 0.49.2 on Ubuntu.

### Changed
- The status line lists only the terminals that are installed.
- Ghostty's safe config editing moved to a shared module used by Ghostty and kitty.

## [1.3.0] - 2026-10-17

### Added
- `--appearance dark|light` keeps iglass dark (or light) while macOS or your Linux desktop
  switches between light and dark mode. The default, `auto`, follows the system as before.
  Works in iTerm2 and Ghostty; `status` shows it, and Ghostty previews follow it.
  ([#2](https://github.com/vukkt/iglass/issues/2))

## [1.2.0] - 2026-10-14

### Added
- **Linux support for Ghostty.** The same palettes, variants, accents and light/dark switching,
  with transparency and blur (blur where the desktop supports it, such as KDE Plasma). Liquid
  Glass stays macOS-only, so `--glass native` is refused on Linux.
- `install.sh` and the Homebrew formula work on Linux; jq is the only extra requirement.
- On desktops that don't blur behind windows (GNOME and most others), `install` defaults to
  Tinted, which stays readable over anything, and warns if you pick Clear or Frosted.
  KDE Plasma and Hyprland keep Frosted. `doctor` says whether your desktop blurs.
- On Linux, fonts are checked with fontconfig, previews start Ghostty directly,
  `--window no-titlebar` hides the GTK title bar, and GNOME's high-contrast setting suggests
  `--contrast high`. State lives in `~/.local/state/iglass`.
- CI runs on Ubuntu as well as macOS, including an end-to-end check against the real Ghostty.

### Fixed
- Uninstalling from Ghostty emptied the Ghostty config when `awk` is GNU awk (the default on
  Fedora and Arch, and on Macs where gawk replaces awk): a variable name iglass used is a
  reserved word there. iglass now also refuses to write the config if that step fails.

### Changed
- `iglass status` and `doctor` show the OS and only the terminals that exist on it.
- iTerm2 options (`--terminal iterm2`, `--app-settings`, `--default`) explain that iTerm2 is
  macOS-only when used on Linux. `export --terminal iterm2` still works anywhere.

## [1.1.1] - 2026-10-13

### Fixed
- `--app-settings` and `--default` didn't notice iTerm2 was running when run from inside
  iTerm2: macOS `pgrep` leaves out its own ancestors, and iTerm2 is one of them. The change
  was written while iTerm2 was open (so it could be overwritten when iTerm2 quit) and iTerm2
  wasn't restarted. iglass now uses `pgrep -a`, and the tests' stand-in behaves like the real
  `pgrep` so this can't regress unnoticed.

## [1.1.0] - 2026-10-13

### Added
- **Ghostty support**, with Apple's real Liquid Glass material (`macos-glass-regular` /
  `macos-glass-clear`) on macOS 26+, and classic blur elsewhere. iglass asks Ghostty's own
  validator whether glass is supported instead of guessing from versions.
- `--terminal iterm2|ghostty|all`; `iglass install` defaults to the terminal it runs in.
- `--glass auto|native|blur` for Ghostty.
- Ghostty edits are minimal and reversible: theme files, an `iglass.ghostty` settings file,
  and one marked include line in the config Ghostty loads last. Symlinked and read-only
  configs are handled; uninstall restores the config byte for byte.
- `doctor`, `status`, `preview` and `export --dir` cover Ghostty.
- Prebuilt Ghostty themes in `themes/ghostty/`.
- Demo GIF and Ghostty screenshots; `tools/record-gif.sh` and a Ghostty mode for
  `tools/screenshots.sh`, both over a generated backdrop.

### Changed
- `install` shows tips only on the first install, and a one-line summary when updating.

### Fixed
- `install.sh` stopped with "unbound variable" when downloading a release (bash 3.2 read the
  `…` in a message as part of a variable name).

## [1.0.0] - 2026-10-13

First release.

### Added
- Four variants inspired by Liquid Glass: Clear, Frosted (default), Tinted and Solid.
- Separate light and dark palettes built from Apple system colors; iTerm2 switches with macOS.
- Eight accent colors matching the macOS accent set.
- `--contrast high`: an increased-contrast palette, following Apple's Liquid Glass guidance.
- Contrast-checked palette build with a generated [contrast report](docs/contrast-report.md).
- `iglass install`, `preview`, `list`, `status`, `doctor`, `export` and `uninstall`.
- Custom profile via `--opacity` / `--blur`; `--cursor`, `--window` and `--font` options.
- Opt-in `--app-settings` (Automatic theme for a system-drawn title bar, padding) and
  `--default`, applied safely while iTerm2 is closed and restored exactly on uninstall.
- Hints for macOS Reduce Transparency and Increase Contrast.
- `install.sh`, Homebrew formula, prebuilt `themes/` for use without the CLI.

[1.6.1]: https://github.com/vukkt/iglass/releases/tag/v1.6.1
[1.6.0]: https://github.com/vukkt/iglass/releases/tag/v1.6.0
[1.5.0]: https://github.com/vukkt/iglass/releases/tag/v1.5.0
[1.4.0]: https://github.com/vukkt/iglass/releases/tag/v1.4.0
[1.3.0]: https://github.com/vukkt/iglass/releases/tag/v1.3.0
[1.2.0]: https://github.com/vukkt/iglass/releases/tag/v1.2.0
[1.1.1]: https://github.com/vukkt/iglass/releases/tag/v1.1.1
[1.1.0]: https://github.com/vukkt/iglass/releases/tag/v1.1.0
[1.0.0]: https://github.com/vukkt/iglass/releases/tag/v1.0.0
