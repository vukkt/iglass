# Changelog

All notable changes to iglass. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [1.2.0] - Unreleased

### Added
- **Linux support for Ghostty.** The same palettes, variants, accents and light/dark switching,
  with transparency and blur (blur where the desktop supports it, such as KDE Plasma). Liquid
  Glass stays macOS-only, so `--glass native` is refused on Linux.
- `install.sh` and the Homebrew formula work on Linux; jq is the only extra requirement.
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

[1.2.0]: https://github.com/vukkt/iglass/releases/tag/v1.2.0
[1.1.1]: https://github.com/vukkt/iglass/releases/tag/v1.1.1
[1.1.0]: https://github.com/vukkt/iglass/releases/tag/v1.1.0
[1.0.0]: https://github.com/vukkt/iglass/releases/tag/v1.0.0
