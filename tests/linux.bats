#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031  # per-test exports are meant to stay inside each test
# Linux: Ghostty through the ghostty command, XDG paths only, blur instead of Liquid Glass, no
# iTerm2. Runs on any OS: use_linux switches iglass to its Linux code paths.

load helpers

setup() {
  setup_sandbox
  use_linux
  XDG="$IGLASS_GHOSTTY_XDG_DIR"
  AS="$IGLASS_GHOSTTY_APPSUPPORT_DIR"
  unset IGLASS_STATE_DIR
  export XDG_STATE_HOME="$SANDBOX/state-home"
  export XDG_CURRENT_DESKTOP=KDE # blurs; see the GNOME tests for a desktop that doesn't
}

include_line() { printf 'config-file = ?"%s/iglass.ghostty"\n' "$XDG"; }
include_count() { grep -cxF "$(include_line)" "$1" || true; }

@test "linux: installs for Ghostty by default, with state in XDG_STATE_HOME" {
  run "$IGLASS" install
  assert_success_
  assert_output_has "Installed iglass for Ghostty (blur, "
  [[ -f "$XDG/iglass.ghostty" && -f "$XDG/themes/iglass-frosted-dark" ]]
  [[ "$(include_count "$XDG/config.ghostty")" == 1 ]]
  [[ -f "$XDG_STATE_HOME/iglass/state.json" ]]
  [[ ! -e "$(profile_file)" ]]
}

@test "linux: on a desktop without blur, install defaults to Tinted and says why" {
  XDG_CURRENT_DESKTOP=GNOME run "$IGLASS" install
  assert_success_
  assert_output_has "GNOME doesn't blur behind windows, so iglass uses Tinted"
  assert_output_has "(transparency, no blur on this desktop, "
  grep -qx 'theme = light:iglass-tinted-light,dark:iglass-tinted-dark' "$XDG/iglass.ghostty"
  run jq -r '.ghostty.options.variant' "$XDG_STATE_HOME/iglass/state.json"
  [[ "$output" == tinted ]]
}

@test "linux: choosing Clear or Frosted without blur works, with a warning" {
  XDG_CURRENT_DESKTOP=ubuntu:GNOME run "$IGLASS" install --variant frosted
  assert_success_
  assert_output_has "ubuntu doesn't blur behind windows"
  grep -qx 'theme = light:iglass-frosted-light,dark:iglass-frosted-dark' "$XDG/iglass.ghostty"
  XDG_CURRENT_DESKTOP=GNOME run "$IGLASS" install --variant solid
  [[ "$output" != *"doesn't blur"* ]]
}

@test "linux: KDE Plasma and Hyprland keep Frosted as the default" {
  for desktop in KDE Hyprland; do
    XDG_CURRENT_DESKTOP=$desktop run "$IGLASS" install
    [[ "$output" != *"doesn't blur"* ]]
    grep -qx 'theme = light:iglass-frosted-light,dark:iglass-frosted-dark' "$XDG/iglass.ghostty"
  done
}

@test "linux: doctor says whether the desktop blurs" {
  "$IGLASS" install
  XDG_CURRENT_DESKTOP=GNOME run "$IGLASS" doctor
  assert_output_has "GNOME doesn't blur behind windows"
  unset XDG_CURRENT_DESKTOP
  run "$IGLASS" doctor
  assert_output_has "This desktop doesn't blur"
}

@test "linux: uses blur, never Liquid Glass" {
  "$IGLASS" install
  run grep -rq "macos-glass" "$XDG/themes"
  [[ "$status" -eq 1 ]]
  grep -qx 'background-blur = 24' "$XDG/themes/iglass-frosted-dark"
  grep -qx 'background-blur = false' "$XDG/themes/iglass-solid-dark"
  run "$IGLASS" install --glass native
  assert_failure_
  assert_output_has "macOS material"
}

@test "linux: an existing config is restored byte for byte, keeping its permissions" {
  mkdir -p "$XDG"
  printf 'font-size = 14\nbackground = #000000' >"$XDG/config.ghostty"
  chmod 600 "$XDG/config.ghostty"
  cp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/original"
  "$IGLASS" install
  [[ "$(include_count "$XDG/config.ghostty")" == 1 ]]
  [[ -n "$(find "$XDG/config.ghostty" -perm 600)" ]]
  "$IGLASS" uninstall
  cmp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/original"
  [[ ! -e "$XDG/iglass.ghostty" && ! -e "$XDG/themes" ]]
}

@test "linux: a failing awk never empties the config on uninstall" {
  mkdir -p "$XDG"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  "$IGLASS" install
  cp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/installed"
  local real_awk
  real_awk=$(command -v awk)
  cat >"$MOCK_DIR/bin/awk" <<EOF
#!/bin/bash
[[ " \$* " == *" marker="* ]] && { echo "awk: fatal: simulated failure" >&2; exit 2; }
exec "$real_awk" "\$@"
EOF
  chmod +x "$MOCK_DIR/bin/awk"
  run "$IGLASS" uninstall
  assert_output_has "Remove the iglass lines from it yourself"
  cmp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/installed"
}

@test "linux: uninstall removes a config iglass created, and is safe to repeat" {
  "$IGLASS" install
  run "$IGLASS" uninstall
  assert_success_
  run find "$SANDBOX/xdg" -mindepth 1
  [[ -z "$output" ]]
  run "$IGLASS" uninstall
  assert_success_
  assert_output_has "not installed for Ghostty"
}

@test "linux: only XDG config files count; Application Support is a macOS location" {
  mkdir -p "$XDG" "$AS"
  printf 'font-size = 14\n' >"$XDG/config"
  printf 'font-size = 15\n' >"$AS/config"
  "$IGLASS" install
  [[ "$(include_count "$XDG/config")" == 1 ]]
  [[ "$(include_count "$AS/config")" == 0 ]]
}

@test "linux: Ghostty's version comes from ghostty --version" {
  use_linux 1.2.0
  "$IGLASS" install
  [[ "$(include_count "$XDG/config")" == 1 ]] # file name used before Ghostty 1.2.3
  run "$IGLASS" status
  assert_output_has "Ghostty 1.2.0 · Fedora Linux 43"
}

@test "linux: without Ghostty, install explains what's needed" {
  use_linux none
  run "$IGLASS" install
  assert_failure_
  assert_output_has "On Linux iglass works with Ghostty"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "Ghostty is not installed"
}

@test "linux: iTerm2 and its app-wide options are refused" {
  run "$IGLASS" install --terminal iterm2
  assert_failure_
  assert_output_has "iTerm2 is macOS-only"
  run "$IGLASS" install --app-settings
  assert_failure_
  assert_output_has "macOS-only"
  run "$IGLASS" install --default
  assert_failure_
  run "$IGLASS" preview --terminal iterm2
  assert_failure_
  [[ ! -e "$XDG" ]]
}

@test "linux: --terminal all means Ghostty" {
  run "$IGLASS" install --terminal all
  assert_success_
  [[ -f "$XDG/iglass.ghostty" && ! -e "$(profile_file)" ]]
}

@test "linux: export works for both terminals, including native glass for a Mac" {
  run "$IGLASS" export --dir "$SANDBOX/out"
  assert_success_
  grep -qx 'background-blur = 24' "$SANDBOX/out/themes/iglass-frosted-dark"
  run "$IGLASS" export --terminal ghostty --glass native --dir "$SANDBOX/native"
  assert_success_
  grep -qx 'background-blur = macos-glass-regular' "$SANDBOX/native/themes/iglass-frosted-dark"
  run "$IGLASS" export --terminal iterm2
  assert_success_
  jq -e '.Profiles | length == 4' <<<"$output"
}

@test "linux: no-titlebar hides the GTK title bar" {
  "$IGLASS" install --window no-titlebar
  grep -qx 'gtk-titlebar = false' "$XDG/iglass.ghostty"
  run grep -q 'macos-titlebar-style' "$XDG/iglass.ghostty"
  [[ "$status" -eq 1 ]]
}

@test "linux: fonts are checked with fontconfig" {
  MOCK_FC_FONTS="JetBrainsMono-Regular" run "$IGLASS" install --font "JetBrainsMono-Regular 14"
  assert_success_
  grep -qx 'font-family = "Mock Family"' "$XDG/iglass.ghostty"
  grep -qx 'font-size = 14' "$XDG/iglass.ghostty"
  run "$IGLASS" install --font "Missing-Regular"
  assert_failure_
  assert_output_has "fc-list : postscriptname"
}

@test "linux: preview starts a detached Ghostty with the variant's themes" {
  "$IGLASS" install --variant tinted
  run "$IGLASS" preview
  assert_success_
  assert_logged "setsid $IGLASS_GHOSTTY_BIN --theme=light:iglass-tinted-light,dark:iglass-tinted-dark"
  refute_logged "open "
}

@test "linux: GNOME high contrast suggests --contrast high" {
  MOCK_GNOME_HIGH_CONTRAST=1 run "$IGLASS" install
  assert_output_has "High contrast is on in your desktop settings"
  run "$IGLASS" install
  [[ "$output" != *"High contrast"* ]]
}

@test "linux: status, list and doctor show Ghostty only" {
  "$IGLASS" install --accent green
  run "$IGLASS" status
  assert_success_
  assert_output_has "accent green"
  assert_output_has "glass blur"
  [[ "$output" != *"iTerm2"* ]]
  run "$IGLASS" list
  assert_output_has "frosted"
  assert_output_has "green (installed)"
  run "$IGLASS" doctor
  assert_success_
  assert_output_has "Fedora Linux 43"
  assert_output_has "KDE blurs behind translucent windows"
  assert_output_has "Included from $XDG/config.ghostty"
  [[ "$output" != *"iTerm2"* && "$output" != *"macOS"* ]]
}

@test "linux: no macOS tools are called" {
  MOCK_FC_FONTS="JetBrainsMono-Regular" "$IGLASS" install --font JetBrainsMono-Regular
  "$IGLASS" preview
  "$IGLASS" status >/dev/null
  "$IGLASS" doctor >/dev/null
  "$IGLASS" uninstall
  refute_logged "osascript"
  refute_logged "open "
  refute_logged "launchctl"
}

@test "linux: generated files pass the real Ghostty validator (skipped without Ghostty on Linux)" {
  [[ "$(uname -s)" == Linux ]] || skip "not running on Linux"
  local real
  real=$(PATH=${PATH#"$MOCK_DIR/bin:"} command -v ghostty) || skip "Ghostty is not installed"
  local accent contrast out home window
  for contrast in standard high; do
    for window in native no-titlebar; do
      for accent in blue graphite; do
        out="$SANDBOX/real-$contrast-$window-$accent"
        "$IGLASS" export --terminal ghostty --contrast "$contrast" --window "$window" \
          --accent "$accent" --opacity 0.8 --dir "$out"
        home="$out/.home"
        mkdir -p "$home/.config/ghostty"
        cp -R "$out/themes" "$home/.config/ghostty/themes"
        cp "$out/iglass.ghostty" "$home/.config/ghostty/config.ghostty"
        HOME="$home" XDG_CONFIG_HOME="$home/.config" "$real" +validate-config
      done
    done
  done
}
