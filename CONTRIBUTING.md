# Contributing

Thanks for helping. Bug reports with `iglass doctor` output, your macOS and iTerm2 versions,
and a screenshot are the most useful thing you can send.

## Setup

```sh
brew install shellcheck bats-core
make check
```

`make check` runs shellcheck, verifies generated files are current, then runs the palette
tests (Python standard library) and the bats suite. Tests are sandboxed: they use temporary
folders, a scratch preferences file and stand-ins for iTerm2, so they never touch your setup.

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
- No runtime dependencies beyond stock macOS 15+ (`jq`, `plutil`, `defaults`, `osascript`).
- Anything written into iTerm2's dynamic profiles folder is validated first and written
  atomically. One unreadable file there disables every dynamic profile.
- User-visible messages say what happened and what to do next.

## Releasing

1. Update `IGLASS_VERSION` in `bin/iglass` and `CHANGELOG.md`.
2. `make check`, commit, tag `vX.Y.Z`, push the tag, publish the GitHub release.
3. Update `url` and `sha256` in the Homebrew formula
   (`curl -fsSL <tarball url> | shasum -a 256`) and push it to the tap.
