#!/bin/bash
# Captures README screenshots of each installed iglass variant running tools/demo.sh.
#
# Usage: tools/screenshots.sh [OUT_DIR] [SUFFIX]
#   OUT_DIR  default docs/screenshots
#   SUFFIX   appended to file names, e.g. "-light" (switch macOS appearance yourself first)
#
# Needs iglass installed (bin/iglass install) and Screen Recording permission for the app
# running this script. Captures the window's screen area, so the wallpaper behind the glass
# shows up as it does on screen.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-$root/docs/screenshots}
suffix=${2:-}
demo="$root/tools/demo.sh"
mkdir -p "$out"

# Window position and size in points: {left, top, right, bottom}.
x=120 y=140 w=760 h=520

capture() { # PROFILE_NAME FILE
  local name=$1 file=$2
  osascript - "$name" "$demo" "$x" "$y" "$((x + w))" "$((y + h))" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2"
    activate
    set win to (create window with profile (item 1 of argv))
    set bounds of win to {(item 3 of argv) as integer, (item 4 of argv) as integer, (item 5 of argv) as integer, (item 6 of argv) as integer}
    tell current session of win to write text "clear; '" & (item 2 of argv) & "'"
  end tell
end run
APPLESCRIPT
  sleep 1.5 # let the demo render and the cursor settle
  if ! screencapture -x -R"$x,$y,$w,$h" "$file"; then
    echo "screencapture failed: grant Screen Recording permission and restart the terminal app" >&2
    exit 1
  fi
  osascript -e 'tell application id "com.googlecode.iterm2" to close current window' >/dev/null 2>&1 || true
  echo "wrote ${file#"$root"/}"
}

for variant in $(jq -r '.variantOrder[]' "$root/data/palette.json"); do
  capture "$(jq -r --arg v "$variant" '.variants[$v].name' "$root/data/palette.json")" \
    "$out/$variant$suffix.png"
done
