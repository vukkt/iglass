# Tested with

Every week, CI checks iglass against the latest release of each terminal it can install on
GitHub's machines. The last run, on 2026-11-26 ([its log](https://github.com/vukkt/iglass/actions/runs/45849000226)), checked:

| | Version | What CI checks |
|---|---|---|
| Ghostty (Linux) | 1.4.0 | `ghostty +validate-config` accepts what iglass writes; uninstall restores the config byte for byte |
| kitty (Linux) | 0.51.1 | kitty's own config parser reads what iglass writes; install and uninstall end to end |
| kitty (macOS) | 0.51.0 | the same, on macOS |
| Warp (Linux) | 0.2026.11.18.08.17.stable.06 | what iglass writes, against the settings schema this Warp ships |
| macOS | 15.8.2 | the whole test suite, with macOS's own `plutil`, `defaults` and bash 3.2 |
| Ubuntu | 24.04 | the whole test suite, with gawk |

iTerm2 doesn't run on GitHub's machines, so its tests check the profiles iglass writes with
macOS's own tools instead.

A bot keeps this page up to date; [CONTRIBUTING.md](../CONTRIBUTING.md#how-iglass-maintains-itself)
explains how.
