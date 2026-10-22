# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154  # bats sets $status/$output; the .bats files use $IGLASS
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
#
# Tests run as macOS (IGLASS_PLATFORM=macos) unless they call use_linux, which switches iglass
# to its Linux code paths with a ghostty command on PATH instead of Ghostty.app:
#   MOCK_FC_FONTS="A B"          PostScript names fontconfig (fc-list) knows, with family "Mock Family"
#   MOCK_GNOME_HIGH_CONTRAST=1   GNOME's high-contrast setting is on
#   MOCK_NIRI=26.04              version reported by niri --version (unset: niri isn't there)
#   MOCK_GNOME=51.1              version reported by gnome-shell --version (unset: not there)
#
# fake_ghostty, fake_kitty and fake_warp install stand-ins for those terminals.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
IGLASS="$REPO_ROOT/bin/iglass"

setup_sandbox() {
  SANDBOX="$BATS_TEST_TMPDIR/sand box" # the space is deliberate
  MOCK_DIR="$SANDBOX/mock"
  MOCK_LOG="$MOCK_DIR/calls.log"
  mkdir -p "$MOCK_DIR/bin" "$SANDBOX/profiles"
  : >"$MOCK_LOG"

  export NO_COLOR=1
  export IGLASS_PLATFORM=macos
  # A sandboxed home: nothing a test runs can reach the real ~/.config or ~/Library.
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
  unset XDG_CONFIG_HOME XDG_CONFIG_DIRS KITTY_CONFIG_DIRECTORY KITTY_WINDOW_ID
  export IGLASS_DYNPROFILES_DIR="$SANDBOX/profiles"
  export IGLASS_STATE_DIR="$SANDBOX/state"
  export IGLASS_PREFS_DOMAIN="$SANDBOX/prefs"
  export IGLASS_ITERM_APP="$SANDBOX/iTerm.app"
  export IGLASS_A11Y_DOMAIN="$SANDBOX/universalaccess"
  export IGLASS_GHOSTTY_APP="$SANDBOX/no-ghostty.app" # fake_ghostty installs one
  export IGLASS_GHOSTTY_XDG_DIR="$SANDBOX/xdg/ghostty"
  export IGLASS_GHOSTTY_APPSUPPORT_DIR="$SANDBOX/appsupport/com.mitchellh.ghostty"
  unset TERM_PROGRAM MOCK_GHOSTTY_REJECT MOCK_GHOSTTY_NO_GLASS
  export IGLASS_APPLY_TIMEOUT=2
  export MOCK_DIR MOCK_LOG
  unset IGLASS_ASSUME_YES MOCK_QUIT_REFUSE MOCK_MISSING_FONTS MOCK_MACOS IGLASS_GHOSTTY_BIN
  unset MOCK_FC_FONTS MOCK_GNOME_HIGH_CONTRAST XDG_STATE_HOME XDG_CURRENT_DESKTOP MOCK_KITTY_REJECT
  unset MOCK_NIRI MOCK_GNOME XDG_DATA_HOME
  export IGLASS_KITTY_BIN="$SANDBOX/no-kitty" IGLASS_KITTY_APP="$SANDBOX/no-kitty.app" # fake_kitty installs one
  export IGLASS_WARP_APP="$SANDBOX/no-warp.app" IGLASS_WARP_BIN="$SANDBOX/no-warp" # fake_warp installs one

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

iterm_start() { : >"$MOCK_DIR/running.iTerm2"; }
iterm_stop() { rm -f "$MOCK_DIR/running.iTerm2"; }

# A Ghostty.app whose validator mimics Ghostty's: it rejects unknown themes, and rejects the
# macos-glass values when MOCK_GHOSTTY_NO_GLASS is set (as Ghostty releases before them do).
fake_ghostty() {
  export IGLASS_GHOSTTY_APP="$SANDBOX/Ghostty.app"
  mkdir -p "$IGLASS_GHOSTTY_APP/Contents/MacOS"
  cat >"$IGLASS_GHOSTTY_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.mitchellh.ghostty</string>
  <key>CFBundleShortVersionString</key><string>${1:-1.3.1}</string>
</dict></plist>
PLIST
  write_fake_ghostty_bin "$IGLASS_GHOSTTY_APP/Contents/MacOS/ghostty" "${1:-1.3.1}"
}

# Switch iglass to Linux: Linux paths and behavior, a ghostty command instead of Ghostty.app
# (pass "none" for no Ghostty), and an os-release file.
use_linux() {
  export IGLASS_PLATFORM=linux
  export IGLASS_GHOSTTY_APP="$SANDBOX/no-ghostty.app"
  export IGLASS_OS_RELEASE="$SANDBOX/os-release"
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$IGLASS_OS_RELEASE"
  if [[ "${1:-}" == none ]]; then
    export IGLASS_GHOSTTY_BIN="$SANDBOX/no-ghostty"
  else
    export IGLASS_GHOSTTY_BIN="$SANDBOX/linux/ghostty"
    mkdir -p "$SANDBOX/linux"
    write_fake_ghostty_bin "$IGLASS_GHOSTTY_BIN" "${1:-1.3.1}"
  fi
}

# A kitty command (both platforms use IGLASS_KITTY_BIN in tests). Its validator mimics kitty's
# parser: MOCK_KITTY_REJECT makes it report a bad file the way kitty does.
fake_kitty() { # [VERSION]
  export IGLASS_KITTY_BIN="$SANDBOX/kitty-bin/kitty"
  mkdir -p "$SANDBOX/kitty-bin"
  cat >"$IGLASS_KITTY_BIN" <<'KITTY'
#!/bin/bash
echo "kitty $*" >>"$MOCK_LOG"
case "$1" in
  --version) echo "kitty @VERSION@ created by Kovid Goyal" ;;
  +runpy)
    shift 2
    [[ -n "${MOCK_KITTY_REJECT:-}" ]] && { echo "[0.01] Ignoring unknown config key: rejected_by_mock" >&2; exit 0; }
    for f in "$@"; do [[ -r "$f" ]] || { echo "No such file: $f" >&2; exit 1; }; done
    ;;
esac
exit 0
KITTY
  sed -i.bak "s/@VERSION@/${1:-0.49.2}/" "$IGLASS_KITTY_BIN" && rm -f "$IGLASS_KITTY_BIN.bak"
  chmod +x "$IGLASS_KITTY_BIN"
}

# Warp: Warp.app on macOS, a warp-terminal command on Linux, each with the settings schema Warp
# ships (tests/fixtures holds the part of Warp's real schema iglass uses). Pass "no-schema" for a
# Warp from before settings.toml.
fake_warp() { # [no-schema]
  local resources
  if [[ "$IGLASS_PLATFORM" == linux ]]; then
    export IGLASS_WARP_BIN="$SANDBOX/warp/warp-terminal"
    mkdir -p "$SANDBOX/warp"
    printf '#!/bin/bash\necho "warp-terminal $*" >>"$MOCK_LOG"\n' >"$IGLASS_WARP_BIN"
    chmod +x "$IGLASS_WARP_BIN"
    resources="$SANDBOX/warp/resources"
  else
    export IGLASS_WARP_APP="$SANDBOX/Warp.app"
    mkdir -p "$IGLASS_WARP_APP/Contents"
    cat >"$IGLASS_WARP_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.warp.Warp-Stable</string>
  <key>CFBundleShortVersionString</key><string>0.2026.10.14.08.27.03</string>
  <key>WarpVersion</key><string>v0.2026.10.14.08.27.stable_03</string>
</dict></plist>
PLIST
    resources="$IGLASS_WARP_APP/Contents/Resources"
  fi
  if [[ "${1:-}" != no-schema ]]; then
    mkdir -p "$resources"
    cp "$REPO_ROOT/tests/fixtures/warp-settings-schema.json" "$resources/settings_schema.json"
  fi
}

# write_fake_ghostty_bin PATH VERSION — a ghostty whose validator mimics Ghostty's.
write_fake_ghostty_bin() {
  cat >"$1" <<'GHOSTTY'
#!/bin/bash
echo "ghostty $*" >>"$MOCK_LOG"
if [[ "$1" == --version ]]; then
  echo "Ghostty @VERSION@"
  echo
  echo "Version"
  exit 0
fi
[[ "$1" == +validate-config ]] || exit 0
[[ -n "${MOCK_GHOSTTY_REJECT:-}" ]] && { echo "rejected by mock" >&2; exit 1; }
dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
config="$dir/config.ghostty"
[[ -f "$config" ]] || exit 0
if [[ -n "${MOCK_GHOSTTY_NO_GLASS:-}" ]] && grep -rq "macos-glass" "$dir"; then
  echo "background-blur: invalid value" >&2
  exit 1
fi
theme=$(sed -n 's/^theme = //p' "$config")
for t in $(tr ',' ' ' <<<"$theme"); do
  t=${t#light:}
  t=${t#dark:}
  [[ -f "$dir/themes/$t" ]] || { echo "theme \"$t\" not found" >&2; exit 1; }
done
exit 0
GHOSTTY
  sed -i.bak "s/@VERSION@/$2/" "$1" && rm -f "$1.bak"
  chmod +x "$1"
}

write_mocks() {
  cat >"$MOCK_DIR/bin/pgrep" <<'EOF'
#!/bin/bash
# Like the real macOS pgrep when iglass runs inside the terminal it manages: without -a, the
# terminal is one of pgrep's ancestors and is left out of the results. Linux pgrep has no
# such filter.
[[ "$(uname -s)" == Linux || " $* " == *" -a "* ]] || exit 1
[[ -f "$MOCK_DIR/running.${*: -1}" ]] # pgrep [-a] -x NAME
EOF

  # setsid -f CMD…: how iglass starts Ghostty windows on Linux.
  cat >"$MOCK_DIR/bin/setsid" <<'EOF'
#!/bin/bash
[[ "$1" == -f ]] && shift
echo "setsid $*" >>"$MOCK_LOG"
EOF

  # fc-list :postscriptname=NAME family
  cat >"$MOCK_DIR/bin/fc-list" <<'EOF'
#!/bin/bash
name=${1#:postscriptname=}
for f in ${MOCK_FC_FONTS:-}; do
  [[ "$f" == "$name" ]] && echo "Mock Family,Mock Family Alias"
done
exit 0
EOF

  cat >"$MOCK_DIR/bin/gsettings" <<'EOF'
#!/bin/bash
[[ -n "${MOCK_GNOME_HIGH_CONTRAST:-}" ]] && echo true || echo false
EOF

  # Desktop versions, which decide blur on niri and GNOME.
  cat >"$MOCK_DIR/bin/niri" <<'EOF'
#!/bin/bash
[[ -n "${MOCK_NIRI:-}" ]] || exit 127
echo "niri $MOCK_NIRI (b35bcae)"
EOF

  cat >"$MOCK_DIR/bin/gnome-shell" <<'EOF'
#!/bin/bash
[[ -n "${MOCK_GNOME:-}" ]] || exit 127
echo "GNOME Shell $MOCK_GNOME"
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
    [[ -n "${MOCK_QUIT_REFUSE:-}" ]] || rm -f "$MOCK_DIR/running.iTerm2"
  else
    echo "osascript -e $2" >>"$MOCK_LOG"
  fi
  exit 0
fi
if [[ "$1" == -l ]]; then # JXA font lookups: osascript -l JavaScript - NAME
  script=$(cat)
  for f in ${MOCK_MISSING_FONTS:-}; do
    if [[ "$f" == "$4" ]]; then
      [[ "$script" == *familyName* ]] || echo missing
      exit 0
    fi
  done
  if [[ "$script" == *familyName* ]]; then echo "Mock Family"; else echo ok; fi
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
