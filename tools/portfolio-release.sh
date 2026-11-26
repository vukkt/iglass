#!/bin/bash
# Points the portfolio (github.com/vukkt/vuk-portfolio) at an iglass release: its "Latest
# release" line, e.g. "iglass 1.7.1 · fixes · November 2026", and the version on the iglass
# project card, e.g. "v1.7". The Release workflow runs it; Autopilot uses --line to check it.
#
# Usage: tools/portfolio-release.sh PORTFOLIO_DIR TAG TITLE PUBLISHED_AT
#        tools/portfolio-release.sh --line TAG TITLE PUBLISHED_AT
#   TAG is vX.Y.Z, TITLE the release's title ("iglass X.Y.Z: what it brings"), PUBLISHED_AT
#   when it was published (2026-11-15T08:12:35Z). The first form edits the portfolio's content
#   file and prints the new line; --line only prints the line the portfolio should show.

set -euo pipefail

usage() { sed -n '6,7p' "${BASH_SOURCE[0]}" | sed 's/^# //' >&2; exit 2; }
(($# == 4)) || usage
dir=$1 tag=$2 title=$3 published=$4

[[ "$tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { echo "Not a release tag: $tag" >&2; exit 1; }
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}

# A patch release is "fixes". Otherwise the title's part after the colon, up to its first comma
# or " for ": "iglass 1.7.0: Tab completion, clearer help…" → "Tab completion".
if ((patch > 0)); then
  version="$major.$minor.$patch" what="fixes"
else
  version="$major.$minor" what="new features"
  if [[ "$title" == *": "* ]]; then
    what=${title#*: }
    what=${what%%,*}
    what=${what%% for *}
  fi
fi
month=$(date -u -d "$published" '+%B %Y' 2>/dev/null ||
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$published" '+%B %Y')
line="iglass $version · $what · $month"
chip="v$major.$minor"

if [[ "$dir" == --line ]]; then
  printf '%s\n' "$line"
  exit 0
fi

json="$dir/.skills/vuk-portfolio/data/portfolio_content.json"
[[ -f "$json" ]] || { echo "No portfolio content file: $json" >&2; exit 1; }
new=$(jq --arg line "$line" --arg chip "$chip" '
  (.hero.glance[] | select(.label == "Latest release") | .value) = $line
  | (.projects[] | select(.id == "iglass") | .facts) |= map(if test("^v[0-9]+\\.[0-9]+$") then $chip else . end)
' "$json")
# If the portfolio's layout changed, say so rather than write a file that doesn't show it.
[[ "$(jq -r '.hero.glance[] | select(.label == "Latest release") | .value' <<<"$new")" == "$line" ]] ||
  { echo "The portfolio has no \"Latest release\" line in hero.glance any more." >&2; exit 1; }
printf '%s\n' "$new" >"$json"
printf '%s\n' "$line"
