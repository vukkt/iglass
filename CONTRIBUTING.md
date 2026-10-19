# Contributing

Thanks for helping. Bug reports with `iglass doctor` output, your OS and terminal versions
(on Linux, your desktop too: KDE, GNOME, …) and a screenshot are the most useful thing you can send.

## Setup

```sh
brew install shellcheck bats-core              # macOS
sudo apt install jq shellcheck bats python3    # Linux (or your distro's equivalents)
make check
```

`make check` runs shellcheck, verifies generated files are current, then runs the palette
tests (Python standard library) and the bats suite. Tests are sandboxed: they use temporary
folders, a scratch preferences file and stand-ins for iTerm2, so they never touch your setup.

Every test runs with a sandboxed `HOME`, so nothing can reach your real configuration.
`tests/kitty.bats` runs on both systems and, when kitty is installed, checks the generated files
with kitty's own parser. `tests/linux.bats` covers Linux and runs on both systems: it sets `IGLASS_PLATFORM=linux`,
which switches iglass to its Linux code paths. The suites tagged `macos` need macOS tools
(`plutil`, `defaults`), so `make test` skips them on Linux. CI runs both, and on Ubuntu also
checks iglass end to end against the real Ghostty.

## Changing colors

Edit [`design/palettes.json`](design/palettes.json), never `data/palette.json` (generated).
Then:

```sh
make palettes themes
```

Check [`docs/contrast-report.md`](docs/contrast-report.md) for what the build adjusted. If a
change makes a target unreachable, the build stops and names the color.

## Code style

- Bash 3.2 compatible (the version macOS ships): no associative arrays, `mapfile`, `${x,,}`.
- No runtime dependencies beyond stock macOS 15+ (`jq`, `plutil`, `defaults`, `osascript`);
  on Linux, only `jq` (fontconfig and `gsettings` are used when present).
- Anything that differs between macOS and Linux goes through [`lib/platform.sh`](lib/platform.sh)
  (`is_macos`/`is_linux`, `file_mode`, `proc_running`, …). Don't call BSD- or GNU-only flags
  directly: `stat -f`, for example, means something unrelated on Linux and still succeeds.
- Anything written into iTerm2's dynamic profiles folder is validated first and written
  atomically. One unreadable file there disables every dynamic profile.
- User-visible messages say what happened and what to do next.

## Releasing

`main` is protected: changes land through pull requests once CI passes on macOS and Linux.

1. In a pull request: update `IGLASS_VERSION` in `bin/iglass`, `CHANGELOG.md`, and
   `make themes`. Merge it when CI is green.
2. Tag the merge commit `vX.Y.Z`, push the tag, publish the GitHub release.
3. Update `url` and `sha256` in the tap's formula
   (`curl -fsSL <tarball url> | shasum -a 256`), run `brew audit --strict --online iglass`,
   and push it to the tap. Mirror the same change into `packaging/homebrew/iglass.rb` with the
   next pull request.
