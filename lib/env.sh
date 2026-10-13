# shellcheck shell=bash
# shellcheck disable=SC2034  # these are read by the other lib/ modules
# Paths and settings. Every location can be overridden with an environment variable, which
# is how the test suite keeps iglass away from real iTerm2 files and preferences.

: "${IGLASS_ROOT:?IGLASS_ROOT must be set by bin/iglass}"

IGLASS_PALETTE="${IGLASS_PALETTE:-$IGLASS_ROOT/data/palette.json}"
IGLASS_DYNPROFILES_DIR="${IGLASS_DYNPROFILES_DIR:-$HOME/Library/Application Support/iTerm2/DynamicProfiles}"
IGLASS_STATE_DIR="${IGLASS_STATE_DIR:-$HOME/Library/Application Support/iglass}"
IGLASS_PREFS_DOMAIN="${IGLASS_PREFS_DOMAIN:-com.googlecode.iterm2}"
IGLASS_A11Y_DOMAIN="${IGLASS_A11Y_DOMAIN:-com.apple.universalaccess}"
IGLASS_ITERM_BUNDLE_ID="com.googlecode.iterm2"
IGLASS_ITERM_PROCESS="${IGLASS_ITERM_PROCESS:-iTerm2}"
IGLASS_APPLY_TIMEOUT="${IGLASS_APPLY_TIMEOUT:-60}"

IGLASS_PROFILE_FILE="$IGLASS_DYNPROFILES_DIR/iglass.json"
IGLASS_STATE_FILE="$IGLASS_STATE_DIR/state.json"

IGLASS_MIN_MACOS="15.0"     # first release that ships /usr/bin/jq
IGLASS_MIN_ITERM="3.5.0"    # first release with separate light/dark colors

# version_ge A B — true when dotted version A >= B.
version_ge() {
  local IFS=.
  local -a a b
  read -r -a a <<<"$1"
  read -r -a b <<<"$2"
  local i x y
  for ((i = 0; i < 4; i++)); do
    x=${a[i]:-0} y=${b[i]:-0}
    x=${x%%[!0-9]*} y=${y%%[!0-9]*}
    x=${x:-0} y=${y:-0}
    if ((10#$x > 10#$y)); then return 0; fi
    if ((10#$x < 10#$y)); then return 1; fi
  done
  return 0
}

require_jq() {
  command -v jq >/dev/null 2>&1 ||
    die "jq is not available." "iglass needs macOS $IGLASS_MIN_MACOS or later, which includes /usr/bin/jq."
}

require_palette() {
  [[ -r "$IGLASS_PALETTE" ]] ||
    die "Color data not found at $IGLASS_PALETTE." "Reinstall iglass; the data/ folder is missing."
}
