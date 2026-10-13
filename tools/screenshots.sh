#!/bin/bash
# Captures README screenshots of each iglass variant running tools/demo.sh.
#
# Usage: tools/screenshots.sh [OUT_DIR] [SUFFIX] [TERMINAL]
#   OUT_DIR   default docs/screenshots
#   SUFFIX    appended to file names, e.g. "-light" (switch macOS appearance yourself first)
#   TERMINAL  iterm2 (default) or ghostty; Ghostty shots are named ghostty-<variant><suffix>.png
#
# Needs Screen Recording permission for the app running this script. For iTerm2, iglass must
# be installed (bin/iglass install). For Ghostty, the themes are generated into a scratch
# folder and Ghostty runs with only them, so the user's own Ghostty config never shows up.
#
# Glass shows whatever is behind it. To keep shots identical between runs, and to never
# capture other windows or anything personal, each shot is taken over a generated backdrop
# (tools/backdrop.py) shown in a temporary, opaque iTerm2 window. Everything temporary is
# removed when the script exits, even on failure.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-$root/docs/screenshots}
suffix=${2:-}
terminal=${3:-iterm2}
demo="$root/tools/demo.sh"
profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
backdrop_profile="$profiles_dir/iglass-screenshot-backdrop.json"
backdrop_name="iglass Screenshot Backdrop"
ghostty_app=/Applications/Ghostty.app
mkdir -p "$out"

# Capture area in points (iTerm2), and the backdrop around it: {left, top, right, bottom}.
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

if [[ "$terminal" == ghostty ]]; then
  # Ghostty sizes windows in cells, so give the backdrop a generous margin all around.
  backdrop_window=$(open_window "$backdrop_name" 40 60 1060 820)
else
  backdrop_window=$(open_window "$backdrop_name" $((x - margin)) $((y - margin)) \
    $((x + w + margin)) $((y + h + margin)))
fi
osascript -e "tell application id \"com.googlecode.iterm2\" to tell current session of (window id $backdrop_window) to write text \"clear\"" >/dev/null

capture_iterm2() { # PROFILE_NAME FILE
  local id
  id=$(open_window "$1" "$x" "$y" "$((x + w))" "$((y + h))")
  osascript - "$id" "$demo" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2" to tell current session of (window id ((item 1 of argv) as integer)) to write text "clear; '" & (item 2 of argv) & "'"
end run
APPLESCRIPT
  sleep 2.5 # let the demo finish, the title settle and the blur update
  screencapture -x -R"$x,$y,$w,$h" "$2" || {
    echo "screencapture failed: grant Screen Recording permission and restart the terminal app" >&2
    exit 1
  }
  osascript -e "tell application id \"com.googlecode.iterm2\" to close (window id $id)" >/dev/null 2>&1 || true
  echo "wrote ${2#"$root"/}"
}

# Bounds "x,y,w,h" of the frontmost window of an app, from the window server.
window_bounds() { # APP_NAME
  osascript -l JavaScript - "$1" <<'JXA'
ObjC.import("CoreGraphics");
function run(argv) {
  const list = ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0));
  for (let i = 0; i < list.count; i++) {
    const w = list.objectAtIndex(i);
    if (ObjC.unwrap(w.objectForKey("kCGWindowOwnerName")) === argv[0] &&
        ObjC.unwrap(w.objectForKey("kCGWindowLayer")) === 0) {
      const b = w.objectForKey("kCGWindowBounds");
      const v = (k) => Math.round(ObjC.unwrap(b.objectForKey(k)));
      return [v("X"), v("Y"), v("Width"), v("Height")].join(",");
    }
  }
  return "";
}
JXA
}

capture_ghostty() { # VARIANT FILE
  local mode bounds
  mode=dark
  [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" == Dark ]] || mode=light
  # Included config files load after command-line options, so the settings file used here
  # must not name a theme of its own (it would override --theme).
  open -na "$ghostty_app" --args --config-default-files=false \
    --config-file="$work/ghostty/screenshot.ghostty" --theme="$work/ghostty/themes/iglass-$1-$mode" \
    --window-width=92 --window-height=27 --window-position-x="$x" --window-position-y="$y" \
    --confirm-close-surface=false --auto-update=off \
    "--command=/bin/bash -c \"clear; '$demo'; sleep 600\""
  sleep 3.5 # launch, render, and let the glass settle
  bounds=$(window_bounds Ghostty)
  [[ -n "$bounds" ]] || { echo "could not find the Ghostty window" >&2; exit 1; }
  screencapture -x -R"$bounds" "$2" || {
    echo "screencapture failed: grant Screen Recording permission and restart the terminal app" >&2
    exit 1
  }
  osascript -e 'tell application id "com.mitchellh.ghostty" to quit' >/dev/null 2>&1 || true
  sleep 1.5
  echo "wrote ${2#"$root"/}"
}

if [[ "$terminal" == ghostty ]]; then
  [[ -d "$ghostty_app" ]] || { echo "Ghostty is not installed" >&2; exit 1; }
  NO_COLOR=1 "$root/bin/iglass" export --terminal ghostty --glass native --dir "$work/ghostty" >/dev/null
  grep -v '^theme = ' "$work/ghostty/iglass.ghostty" >"$work/ghostty/screenshot.ghostty"
fi

for variant in $(jq -r '.variantOrder[]' "$root/data/palette.json"); do
  if [[ "$terminal" == ghostty ]]; then
    capture_ghostty "$variant" "$out/ghostty-$variant$suffix.png"
  else
    capture_iterm2 "$(jq -r --arg v "$variant" '.variants[$v].name' "$root/data/palette.json")" \
      "$out/$variant$suffix.png"
  fi
done
