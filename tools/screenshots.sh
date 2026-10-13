#!/bin/bash
# Captures README screenshots of each installed iglass variant running tools/demo.sh.
#
# Usage: tools/screenshots.sh [OUT_DIR] [SUFFIX]
#   OUT_DIR  default docs/screenshots
#   SUFFIX   appended to file names, e.g. "-light" (switch macOS appearance yourself first)
#
# Needs iglass installed (bin/iglass install) and Screen Recording permission for the app
# running this script.
#
# Glass shows whatever is behind it. To keep shots identical between runs, and to never
# capture other windows or anything personal, each shot is taken over a generated backdrop
# (tools/backdrop.py) shown in a temporary, opaque iTerm2 window. The temporary profile and
# window are removed when the script exits, even on failure.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-$root/docs/screenshots}
suffix=${2:-}
demo="$root/tools/demo.sh"
profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
backdrop_profile="$profiles_dir/iglass-screenshot-backdrop.json"
backdrop_name="iglass Screenshot Backdrop"
mkdir -p "$out"

# Capture area in points, and the larger backdrop around it: {left, top, right, bottom}.
x=120 y=140 w=760 h=520
margin=60

work=$(mktemp -d)
backdrop_window=""
cleanup() {
  if [[ -n "$backdrop_window" ]]; then
    osascript -e "tell application id \"com.googlecode.iterm2\" to close (window id $backdrop_window)" \
      >/dev/null 2>&1 || true
  fi
  rm -f "$backdrop_profile"
  rm -rf "$work"
}
trap cleanup EXIT

python3 "$root/tools/backdrop.py" "$work/backdrop.png" 1200 840

# Blend 1 shows the image at full strength (verified; 0 shows only the background color).
jq -n --arg name "$backdrop_name" --arg image "$work/backdrop.png" '{Profiles: [{
  Name: $name, Guid: "8C0F6B2E-3F7A-4C55-9C1D-2B6A1F0E9D47", Tags: ["iglass"],
  "Background Image Location": $image, "Background Image Mode": 2, Blend: 1,
  Transparency: 0, Blur: false, "Window Type": 12, "Use Separate Colors for Light and Dark Mode": false,
  "Background Color": {"Red Component": 0, "Green Component": 0, "Blue Component": 0,
                       "Alpha Component": 1, "Color Space": "sRGB"},
  "Cursor Type": 1, "Blinking Cursor": false
}]}' >"$work/backdrop.json"
plutil -convert xml1 -o /dev/null "$work/backdrop.json" # never put an unreadable file there
cp "$work/backdrop.json" "$backdrop_profile"

open_window() { # PROFILE LEFT TOP RIGHT BOTTOM → prints the window id
  osascript - "$@" <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2"
    activate
    repeat 20 times
      try
        set win to (create window with profile (item 1 of argv))
        exit repeat
      on error
        delay 0.3 -- the profiles folder is reloaded asynchronously
      end try
    end repeat
    set bounds of win to {(item 2 of argv) as integer, (item 3 of argv) as integer, (item 4 of argv) as integer, (item 5 of argv) as integer}
    return id of win
  end tell
end run
APPLESCRIPT
}

backdrop_window=$(open_window "$backdrop_name" $((x - margin)) $((y - margin)) \
  $((x + w + margin)) $((y + h + margin)))
osascript -e "tell application id \"com.googlecode.iterm2\" to tell current session of (window id $backdrop_window) to write text \"clear\"" >/dev/null

capture() { # PROFILE_NAME FILE
  local id
  id=$(open_window "$1" "$x" "$y" "$((x + w))" "$((y + h))")
  osascript - "$id" "$demo" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2" to tell current session of (window id ((item 1 of argv) as integer)) to write text "clear; '" & (item 2 of argv) & "'"
end run
APPLESCRIPT
  sleep 2.5 # let the demo finish, the title settle and the blur update
  if ! screencapture -x -R"$x,$y,$w,$h" "$2"; then
    echo "screencapture failed: grant Screen Recording permission and restart the terminal app" >&2
    exit 1
  fi
  osascript -e "tell application id \"com.googlecode.iterm2\" to close (window id $id)" >/dev/null 2>&1 || true
  echo "wrote ${2#"$root"/}"
}

for variant in $(jq -r '.variantOrder[]' "$root/data/palette.json"); do
  capture "$(jq -r --arg v "$variant" '.variants[$v].name' "$root/data/palette.json")" \
    "$out/$variant$suffix.png"
done
