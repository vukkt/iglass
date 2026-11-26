#!/bin/bash
# Prints docs/tested-with.md: the versions the weekly CI run checked iglass against. CI's
# tested-with job runs it with the versions its macos and linux jobs found, and proposes the
# result in a PR that merges itself once CI passes on it.
#
# Usage: GHOSTTY=… KITTY=… KITTY_MACOS=… WARP=… MACOS=… UBUNTU=… tools/tested-with.sh DATE RUN_URL
#   A version left empty shows as "not checked this time" (its download failed, say).

set -euo pipefail

date=${1:?usage: tools/tested-with.sh DATE RUN_URL} run=${2:?usage: tools/tested-with.sh DATE RUN_URL}
v() { printf '%s' "${!1:-not checked this time}"; }

cat <<MARKDOWN
# Tested with

Every week, CI checks iglass against the latest release of each terminal it can install on
GitHub's machines. The last run, on $date ([its log]($run)), checked:

| | Version | What CI checks |
|---|---|---|
| Ghostty (Linux) | $(v GHOSTTY) | \`ghostty +validate-config\` accepts what iglass writes; uninstall restores the config byte for byte |
| kitty (Linux) | $(v KITTY) | kitty's own config parser reads what iglass writes; install and uninstall end to end |
| kitty (macOS) | $(v KITTY_MACOS) | the same, on macOS |
| Warp (Linux) | $(v WARP) | what iglass writes, against the settings schema this Warp ships |
| macOS | $(v MACOS) | the whole test suite, with macOS's own \`plutil\`, \`defaults\` and bash 3.2 |
| Ubuntu | $(v UBUNTU) | the whole test suite, with gawk |

iTerm2 doesn't run on GitHub's machines, so its tests check the profiles iglass writes with
macOS's own tools instead.

A bot keeps this page up to date; [CONTRIBUTING.md](../CONTRIBUTING.md#how-iglass-maintains-itself)
explains how.
MARKDOWN
