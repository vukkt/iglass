#!/bin/bash
# Prints the GitHub release notes for a version: its section of CHANGELOG.md, then how to update.
#
# Usage: tools/release-notes.sh VERSION
#   gh release create vX.Y.Z --verify-tag --title "iglass X.Y.Z: …" --notes-file <(tools/release-notes.sh X.Y.Z)

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=${1:?usage: tools/release-notes.sh VERSION}

# From "## [VERSION] - date" up to the next version or the link list, without blank edges.
notes=$(awk -v v="$version" '
  index($0, "## [" v "] - ") == 1 { on = 1; next }
  on && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  on { print }' "$root/CHANGELOG.md" | sed -e '/./,$!d')
[[ -n "$notes" ]] || { echo "CHANGELOG.md has no section for $version." >&2; exit 1; }

printf '%s\n\n%s\n' "$notes" '**Install or update:** `brew upgrade iglass`, or rerun the install script.'
