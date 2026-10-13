# Changelog

All notable changes to iglass. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

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
- Opt-in `--app-settings` (Minimal theme, padding) and `--default`, applied safely while
  iTerm2 is closed and restored exactly on uninstall.
- Hints for macOS Reduce Transparency and Increase Contrast.
- `install.sh`, Homebrew formula, prebuilt `themes/` for use without the CLI.

[1.0.0]: https://github.com/vukkt/iglass/releases/tag/v1.0.0
