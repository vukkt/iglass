#!/bin/bash
# Records docs/demo.gif: an iTerm2 window using "iglass Custom" turns glassier and changes
# accent live while `iglass install` commands are typed into it.
#
# Usage: tools/record-gif.sh [OUT.gif]
# Needs iTerm2, ffmpeg and Screen Recording permission for the app running this script.
#
# The window runs a clean bash (no history, no autosuggestions, no personal prompt) over a
# generated backdrop. The current iglass install is saved first and restored exactly at the
# end, even on failure.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-$root/docs/demo.gif}
iglass="$root/bin/iglass"
profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
state_dir="$HOME/Library/Application Support/iglass"
backdrop_profile="$profiles_dir/iglass-screenshot-backdrop.json"
backdrop_name="iglass Screenshot Backdrop"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required (brew install ffmpeg)" >&2; exit 1; }

x=120 y=140 w=760 h=520 margin=60
work=$(mktemp -d)
backdrop_window="" demo_window=""

# Save the user's install so it can be put back byte for byte.
cp -p "$profiles_dir/iglass.json" "$work/saved-profile.json" 2>/dev/null || true
cp -p "$state_dir/state.json" "$work/saved-state.json" 2>/dev/null || true

cleanup() {
  local id
  for id in "$demo_window" "$backdrop_window"; do
    if [[ -n "$id" ]]; then
      osascript -e "tell application id \"com.googlecode.iterm2\" to close (window id $id)" >/dev/null 2>&1 || true
    fi
  done
  rm -f "$backdrop_profile"
  if [[ -f "$work/saved-profile.json" ]]; then
    cp -p "$work/saved-profile.json" "$profiles_dir/iglass.json"
  else
    rm -f "$profiles_dir/iglass.json"
  fi
  if [[ -f "$work/saved-state.json" ]]; then
    cp -p "$work/saved-state.json" "$state_dir/state.json"
  fi
  rm -rf "$work"
}
trap cleanup EXIT

python3 "$root/tools/backdrop.py" "$work/backdrop.png" 1200 840
# Blend 1 shows the image at full strength.
jq -n --arg name "$backdrop_name" --arg image "$work/backdrop.png" '{Profiles: [{
  Name: $name, Guid: "8C0F6B2E-3F7A-4C55-9C1D-2B6A1F0E9D47", Tags: ["iglass"],
  "Background Image Location": $image, "Background Image Mode": 2, Blend: 1,
  Transparency: 0, Blur: false, "Window Type": 12, "Use Separate Colors for Light and Dark Mode": false
}]}' >"$work/backdrop.json"
plutil -convert xml1 -o /dev/null "$work/backdrop.json"
cp "$work/backdrop.json" "$backdrop_profile"

NO_COLOR=1 "$iglass" install --terminal iterm2 --opacity 0.95 >/dev/null

# A clean shell: fixed prompt, iglass on PATH, a few lines of color to start with.
cat >"$work/rc" <<RC
PS1='\[\e[32m\]❯\[\e[0m\] '
PATH="$root/bin:\$PATH"
unset HISTFILE
clear
"$root/tools/demo.sh" | tail -n 5
RC

open_window() { # PROFILE LEFT TOP RIGHT BOTTOM [COMMAND] → prints the window id
  osascript - "$@" <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2"
    activate
    repeat 20 times
      try
        if (count of argv) > 5 then
          set win to (create window with profile (item 1 of argv) command (item 6 of argv))
        else
          set win to (create window with profile (item 1 of argv))
        end if
        exit repeat
      on error
        delay 0.3
      end try
    end repeat
    set bounds of win to {(item 2 of argv) as integer, (item 3 of argv) as integer, (item 4 of argv) as integer, (item 5 of argv) as integer}
    return id of win
  end tell
end run
APPLESCRIPT
}

type_line() { # TEXT — types it character by character, then presses return
  osascript - "$demo_window" "$1" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application id "com.googlecode.iterm2"
    tell current session of (window id ((item 1 of argv) as integer))
      repeat with c in characters of (item 2 of argv)
        write text (c as string) newline no
        delay 0.045
      end repeat
      delay 0.3
      write text ""
    end tell
  end tell
end run
APPLESCRIPT
}

backdrop_window=$(open_window "$backdrop_name" $((x - margin)) $((y - margin)) $((x + w + margin)) $((y + h + margin)))
demo_window=$(open_window "iglass Custom" "$x" "$y" "$((x + w))" "$((y + h))" \
  "/usr/bin/env BASH_SILENCE_DEPRECATION_WARNING=1 /bin/bash --noprofile --rcfile $work/rc -i")
sleep 2

# Park the mouse pointer outside the recorded area (screen recordings include it).
osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); $.CGWarpMouseCursorPosition({x: 5, y: 5})' >/dev/null
screencapture -x -v -V 17 -R"$x,$y,$w,$h" "$work/demo.mov" &
recorder=$!
sleep 1.2
type_line "iglass install --opacity 0.8"
sleep 1.8
type_line "iglass install --opacity 0.6 --force --accent pink"
sleep 2
type_line "iglass install --opacity 0.6 --force --accent green"
wait "$recorder"

# GIF: 10 fps, 760 px wide, one 256-color palette for the whole clip (smooth gradients);
# only the changed part of each frame is re-encoded (diff_mode=rectangle), which keeps a
# mostly static terminal small.
ffmpeg -v error -y -i "$work/demo.mov" -vf \
  "fps=10,scale=760:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 "$out"
echo "wrote ${out#"$root"/} ($(du -h "$out" | cut -f1))"
