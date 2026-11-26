# Contributing

Thanks for helping. Bug reports with `iglass doctor` output, your OS and terminal versions
(on Linux, your desktop too: KDE, GNOME, …) and a screenshot are the most useful thing you can send.

## Setup

```sh
brew install shellcheck bats-core fish                   # macOS
sudo apt install jq shellcheck bats python3 zsh fish     # Linux (or your distro's equivalents)
make check
```

`make check` runs shellcheck, verifies generated files are current, then runs the palette
tests (Python standard library) and the bats suite. Tests are sandboxed: they use temporary
folders, a scratch preferences file and stand-ins for iTerm2, so they never touch your setup.

Every test runs with a sandboxed `HOME`, so nothing can reach your real configuration.
`tests/kitty.bats` runs on both systems and, when kitty is installed, checks the generated files
with kitty's own parser. `tests/warp.bats` also runs on both, against a stand-in Warp that ships
the relevant part of Warp's real settings schema (`tests/fixtures`). `tests/linux.bats` covers Linux and runs on both systems: it sets `IGLASS_PLATFORM=linux`,
which switches iglass to its Linux code paths. The suites tagged `macos` need macOS tools
(`plutil`, `defaults`), so `make test` skips them on Linux. CI runs both, and on Ubuntu also
checks iglass end to end against the real Ghostty, kitty and Warp's settings schema
(`tools/check_warp.py`, which needs the `jsonschema` and `PyYAML` packages). It also runs every
Monday, so a new release of one of those terminals that breaks iglass is caught between pushes.

`tests/completions.bats` presses Tab in bash, zsh (in a pseudo-terminal, `tests/complete.zsh`)
and fish; the zsh and fish parts are skipped when those shells aren't installed.

A check written as `[[ … ]]` in the middle of a test must end in `|| false`: macOS's bash 3.2
doesn't stop a test when it fails otherwise.

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
- Temporary files and folders come from `temp_make` ([`lib/temp.sh`](lib/temp.sh)), never
  `mktemp` directly, so iglass removes them even when it's interrupted.
- A new option goes into `--help` and the three files in [`completions/`](completions) too;
  tests check that every option the parser accepts is in all of them.
- User-visible messages say what happened and what to do next.

## Releasing

`main` is protected: changes land through pull requests once CI passes on macOS and Linux.

1. In a pull request: update `IGLASS_VERSION` in `bin/iglass`, add the version's section and
   link to `CHANGELOG.md` (a test checks both), and run `make themes`. Title the PR with what the
   release brings and the version, e.g. "Warp support (1.6.0)": the release is named after it
   ("iglass 1.6.0: Warp support"). Add the `automerge` label, or merge it once CI is green.
2. That's all. When the merge reaches `main`, [Autopilot](#how-iglass-maintains-itself) tags it
   and publishes the release, with its notes taken from the changelog
   (`tools/release-notes.sh`), then starts the [Release workflow](.github/workflows/release.yml).
   That fills in [`packaging/homebrew/iglass.rb`](packaging/homebrew/iglass.rb) with the
   release's url and checksum, runs `brew audit`, `install` and `test` on it, pushes it to
   [vukkt/homebrew-tap](https://github.com/vukkt/homebrew-tap), and then updates the "Latest
   release" line on the [portfolio](https://github.com/vukkt/vuk-portfolio). Change the formula
   in this repo, never in the tap.

Publishing a release by hand still works the same way (`gh release create vX.Y.Z --title
"iglass X.Y.Z: …" --notes-file <(tools/release-notes.sh X.Y.Z)`). If the Release workflow
fails, fix the cause; Autopilot runs it again, or run it from Actions › Release › Run workflow,
with the tag.

## How iglass maintains itself

Bots keep iglass up to date and check each other's work; a person is needed only when one of
them can't fix something by itself.

| What | Who | When |
|---|---|---|
| Test every change on macOS and Linux, with the real Ghostty, kitty and Warp | CI | every PR and push |
| Test against the newest Warp, Ghostty and kitty, and record them in [docs/tested-with.md](docs/tested-with.md) through a PR that merges itself | CI | Mondays |
| Update the GitHub Actions the workflows use, in one PR, once a release is a week old | Dependabot | monthly |
| Merge Dependabot's PRs and PRs labelled `automerge`, once CI passes on them | [Auto-merge](.github/workflows/automerge.yml) | each such PR |
| Publish the release for a new version; check Homebrew and the portfolio are on the latest release, and rerun the Release workflow if not; turn workflows GitHub switched off back on; check the latest CI, Release and Website runs, the weekly run, and stuck bot PRs | [Autopilot](tools/autopilot.sh) | daily, and when the version changes |
| Check Autopilot itself ran and succeeded | CI | Mondays |
| Update Homebrew and the portfolio for a release | [Release](.github/workflows/release.yml) | each release |

When something needs a person, Autopilot opens an issue labelled `autopilot` that says what
and links to the run, and closes it once everything works again. A failed weekly run also
sends GitHub's usual email.

What still takes a person: deciding what iglass should do and replying to people, fixing
iglass when a new terminal release breaks it (the weekly run and Autopilot's issue say so
within a week), and judging how the glass looks.
