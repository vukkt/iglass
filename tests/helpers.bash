# Shared setup for the bats suites.
#
# Every test gets its own sandbox: a temporary profiles folder, state folder, preferences file
# and a fake iTerm.app. System commands iglass talks to (pgrep, osascript, open, launchctl,
# sw_vers, mdfind) are replaced with stand-ins that log what they were asked to do, so tests
# never touch real iTerm2 files, preferences or windows.
#
# Knobs for the stand-ins:
#   iterm_start / iterm_stop     simulate iTerm2 running or not
#   MOCK_QUIT_REFUSE=1           iTerm2 ignores the quit request
#   MOCK_MISSING_FONTS="A B"     fonts that report as not installed
#   MOCK_MACOS=14.6              macOS version reported by sw_vers

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
IGLASS="$REPO_ROOT/bin/iglass"

setup_sandbox() {
  SANDBOX="$BATS_TEST_TMPDIR/sand box" # the space is deliberate
  MOCK_DIR="$SANDBOX/mock"
  MOCK_LOG="$MOCK_DIR/calls.log"
  mkdir -p "$MOCK_DIR/bin" "$SANDBOX/profiles"
  : >"$MOCK_LOG"

  export NO_COLOR=1
  export IGLASS_DYNPROFILES_DIR="$SANDBOX/profiles"
  export IGLASS_STATE_DIR="$SANDBOX/state"
  export IGLASS_PREFS_DOMAIN="$SANDBOX/prefs"
  export IGLASS_ITERM_APP="$SANDBOX/iTerm.app"
  export IGLASS_APPLY_TIMEOUT=2
  export MOCK_DIR MOCK_LOG
  unset IGLASS_ASSUME_YES MOCK_QUIT_REFUSE MOCK_MISSING_FONTS MOCK_MACOS

  fake_iterm_version 3.7.4
  write_mocks
  export PATH="$MOCK_DIR/bin:$PATH"
}

fake_iterm_version() {
  mkdir -p "$IGLASS_ITERM_APP/Contents"
  cat >"$IGLASS_ITERM_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.googlecode.iterm2</string>
  <key>CFBundleShortVersionString</key><string>$1</string>
</dict></plist>
EOF
}

iterm_start() { : >"$MOCK_DIR/running"; }
iterm_stop() { rm -f "$MOCK_DIR/running"; }

write_mocks() {
  cat >"$MOCK_DIR/bin/pgrep" <<'EOF'
#!/bin/bash
[[ -f "$MOCK_DIR/running" ]]
EOF

  cat >"$MOCK_DIR/bin/sw_vers" <<'EOF'
#!/bin/bash
echo "${MOCK_MACOS:-27.0.1}"
EOF

  cat >"$MOCK_DIR/bin/mdfind" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$MOCK_DIR/bin/open" <<'EOF'
#!/bin/bash
echo "open $*" >>"$MOCK_LOG"
EOF

  # launchctl submit runs the job right away, in the foreground.
  cat >"$MOCK_DIR/bin/launchctl" <<'EOF'
#!/bin/bash
case "$1" in
  submit)
    label=$3
    shift 4 # submit -l LABEL --
    echo "launchctl submit $label" >>"$MOCK_LOG"
    "$@"
    ;;
  remove) echo "launchctl remove $2" >>"$MOCK_LOG" ;;
esac
EOF

  cat >"$MOCK_DIR/bin/osascript" <<'EOF'
#!/bin/bash
if [[ "$1" == -e ]]; then
  if [[ "$2" == *quit* ]]; then
    echo "osascript quit" >>"$MOCK_LOG"
    [[ -n "${MOCK_QUIT_REFUSE:-}" ]] || rm -f "$MOCK_DIR/running"
  else
    echo "osascript -e $2" >>"$MOCK_LOG"
  fi
  exit 0
fi
if [[ "$1" == -l ]]; then # JXA font check: osascript -l JavaScript - NAME
  for f in ${MOCK_MISSING_FONTS:-}; do
    if [[ "$f" == "$4" ]]; then echo missing; exit 0; fi
  done
  echo ok
  exit 0
fi
script=$(cat)
if [[ "$script" == *"display notification"* ]]; then
  echo "osascript notify $2" >>"$MOCK_LOG"
elif [[ "$script" == *"create window with profile"* ]]; then
  echo "osascript create-window $2" >>"$MOCK_LOG"
  [[ -n "${MOCK_WINDOW_FAIL:-}" ]] && exit 1
fi
exit 0
EOF
  chmod +x "$MOCK_DIR/bin/"*
}

profile_file() { printf '%s\n' "$IGLASS_DYNPROFILES_DIR/iglass.json"; }
state_file() { printf '%s\n' "$IGLASS_STATE_DIR/state.json"; }

# pref KEY — print a preference from the sandbox domain, or <absent>.
pref() {
  defaults read "$IGLASS_PREFS_DOMAIN" "$1" 2>/dev/null || echo "<absent>"
}

assert_success_() {
  if [[ "$status" -ne 0 ]]; then
    echo "expected success, got $status. output:" >&2
    echo "$output" >&2
    return 1
  fi
}

assert_failure_() {
  if [[ "$status" -eq 0 ]]; then
    echo "expected failure. output:" >&2
    echo "$output" >&2
    return 1
  fi
}

assert_output_has() {
  if [[ "$output" != *"$1"* ]]; then
    echo "expected output to contain: $1" >&2
    echo "actual output:" >&2
    echo "$output" >&2
    return 1
  fi
}

assert_logged() {
  if ! grep -qF -- "$1" "$MOCK_LOG"; then
    echo "expected mock log to contain: $1" >&2
    cat "$MOCK_LOG" >&2
    return 1
  fi
}

refute_logged() {
  if grep -qF -- "$1" "$MOCK_LOG"; then
    echo "expected mock log NOT to contain: $1" >&2
    cat "$MOCK_LOG" >&2
    return 1
  fi
}
