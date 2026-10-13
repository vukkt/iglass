# shellcheck shell=bash
# Talking to iTerm2 and macOS: finding the app, its version, whether it runs, fonts, previews.

# Print the path of iTerm.app, or nothing if it is not installed.
iterm_app_path() {
  if [[ -n "${IGLASS_ITERM_APP:-}" ]]; then
    [[ -d "$IGLASS_ITERM_APP" ]] && printf '%s\n' "$IGLASS_ITERM_APP"
    return 0
  fi
  local candidate
  for candidate in "/Applications/iTerm.app" "$HOME/Applications/iTerm.app"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  candidate=$(mdfind "kMDItemCFBundleIdentifier == '$IGLASS_ITERM_BUNDLE_ID'" 2>/dev/null | head -n 1)
  [[ -n "$candidate" && -d "$candidate" ]] && printf '%s\n' "$candidate"
  return 0
}

# Print the installed iTerm2 version (e.g. 3.7.4), or nothing.
iterm_version() {
  local app
  app=$(iterm_app_path)
  [[ -n "$app" ]] || return 0
  plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist" 2>/dev/null || true
}

iterm_running() {
  pgrep -x "$IGLASS_ITERM_PROCESS" >/dev/null 2>&1
}

macos_version() {
  sw_vers -productVersion 2>/dev/null || true
}

# Open a new iTerm2 window using the named profile. iTerm2 reloads the profiles folder
# asynchronously, so a profile written a moment ago may need a few tries to appear.
iterm_open_profile() {
  local name=$1 attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if osascript - "$name" >/dev/null 2>&1 <<'APPLESCRIPT'; then
on run argv
  tell application id "com.googlecode.iterm2" to create window with profile (item 1 of argv)
end run
APPLESCRIPT
      return 0
    fi
    [[ $attempt -lt 10 ]] && sleep 0.4
  done
  return 1
}

# True when a font with this PostScript name is installed.
font_available() {
  local result
  result=$(osascript -l JavaScript - "$1" 2>/dev/null <<'JXA'
ObjC.import("AppKit");
function run(argv) {
  return $.NSFont.fontWithNameSize(argv[0], 13).isNil() ? "missing" : "ok";
}
JXA
)
  [[ "$result" == ok ]]
}

# Print the family name of an installed font, given its PostScript name (Ghostty uses families).
font_family() {
  osascript -l JavaScript - "$1" 2>/dev/null <<'JXA'
ObjC.import("AppKit");
function run(argv) {
  const f = $.NSFont.fontWithNameSize(argv[0], 13);
  return f.isNil() ? "" : ObjC.unwrap(f.familyName);
}
JXA
}

# Which terminal is this running in? Falls back to whichever supported terminal is installed.
detect_terminal() {
  case "${TERM_PROGRAM:-}" in
    ghostty) printf 'ghostty\n' ;;
    iTerm.app) printf 'iterm2\n' ;;
    *)
      if [[ -n "$(iterm_app_path)" ]]; then
        printf 'iterm2\n'
      elif [[ -n "$(ghostty_app_path)" ]]; then
        printf 'ghostty\n'
      else
        printf 'iterm2\n'
      fi
      ;;
  esac
}

# macOS Accessibility › Display settings that iglass adapts to.
reduce_transparency_on() {
  [[ "$(defaults read "$IGLASS_A11Y_DOMAIN" reduceTransparency 2>/dev/null)" == 1 ]]
}

increase_contrast_on() {
  [[ "$(defaults read "$IGLASS_A11Y_DOMAIN" increaseContrast 2>/dev/null)" == 1 ]]
}

# Suggest the variant and contrast that match the user's accessibility settings.
accessibility_hints() { # VARIANT CONTRAST
  if reduce_transparency_on && [[ "$1" != solid ]]; then
    ui_info "Reduce transparency is on in macOS; iglass Solid matches it: iglass install --variant solid"
  fi
  if increase_contrast_on && [[ "$2" != high ]]; then
    ui_info "Increase contrast is on in macOS; try stronger colors: iglass install --contrast high"
  fi
}
