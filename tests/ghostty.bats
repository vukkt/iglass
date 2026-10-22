#!/usr/bin/env bats
# bats file_tags=macos
# shellcheck disable=SC2030,SC2031  # per-test exports are meant to stay inside each test
# Ghostty support: theme files, the include line in the user's config, glass detection.

load helpers

setup() {
  setup_sandbox
  fake_ghostty
  XDG="$IGLASS_GHOSTTY_XDG_DIR"
  AS="$IGLASS_GHOSTTY_APPSUPPORT_DIR"
}

include_line() { printf 'config-file = ?"%s/iglass.ghostty"\n' "$XDG"; }
include_count() { grep -cxF "$(include_line)" "$1" || true; }

@test "installs themes and settings, and creates a config when there is none" {
  run "$IGLASS" install --terminal ghostty
  assert_success_
  assert_output_has "Installed iglass for Ghostty"
  run ls "$XDG/themes"
  [[ $(wc -l <<<"$output") -eq 8 ]] || false
  [[ -f "$XDG/iglass.ghostty" ]] || false
  [[ "$(include_count "$XDG/config.ghostty")" == 1 ]] || false
  run jq -r '.ghostty.createdConfig' "$(state_file)"
  [[ "$output" == true ]] || false
  [[ ! -e "$(profile_file)" ]] || false # iTerm2 untouched
}

@test "uninstall removes everything, including a config it created" {
  "$IGLASS" install --terminal ghostty
  run "$IGLASS" uninstall --terminal ghostty
  assert_success_
  run find "$SANDBOX/xdg" -mindepth 1
  [[ -z "$output" ]] || false
}

@test "an existing config is restored byte for byte, even without a final newline" {
  mkdir -p "$XDG"
  printf 'font-size = 14\n# my comment\nbackground = #000000' >"$XDG/config.ghostty"
  cp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/original"
  "$IGLASS" install --terminal ghostty
  [[ "$(include_count "$XDG/config.ghostty")" == 1 ]] || false
  grep -qx 'background = #000000' "$XDG/config.ghostty" # not glued to iglass's lines
  "$IGLASS" uninstall --terminal ghostty
  cmp "$XDG/config.ghostty" "$BATS_TEST_TMPDIR/original"
}

@test "the first config is backed up before iglass edits it" {
  mkdir -p "$XDG"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  "$IGLASS" install --terminal ghostty
  "$IGLASS" install --terminal ghostty --accent pink
  cmp "$IGLASS_STATE_DIR/backups/ghostty-config-before-iglass" <(printf 'font-size = 14\n')
}

@test "the include goes into the config Ghostty loads last" {
  mkdir -p "$XDG" "$AS"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  printf 'font-size = 15\n' >"$AS/config"
  "$IGLASS" install --terminal ghostty
  [[ "$(include_count "$AS/config")" == 1 ]] || false
  [[ "$(include_count "$XDG/config.ghostty")" == 0 ]] || false
}

@test "a new config uses the old file name for Ghostty before 1.2.3" {
  fake_ghostty 1.2.0
  "$IGLASS" install --terminal ghostty
  [[ "$(include_count "$XDG/config")" == 1 ]] || false
}

@test "reinstalling never duplicates the include" {
  "$IGLASS" install --terminal ghostty
  "$IGLASS" install --terminal ghostty --accent green
  "$IGLASS" install --terminal ghostty --variant clear
  [[ "$(include_count "$XDG/config.ghostty")" == 1 ]] || false
}

@test "a symlinked config (dotfiles) stays a symlink; its target is edited" {
  mkdir -p "$XDG" "$SANDBOX/dotfiles"
  printf 'font-size = 14\n' >"$SANDBOX/dotfiles/ghostty.conf"
  ln -s "$SANDBOX/dotfiles/ghostty.conf" "$XDG/config.ghostty"
  "$IGLASS" install --terminal ghostty
  [[ -L "$XDG/config.ghostty" ]] || false
  [[ "$(include_count "$SANDBOX/dotfiles/ghostty.conf")" == 1 ]] || false
  "$IGLASS" uninstall --terminal ghostty
  [[ -L "$XDG/config.ghostty" ]] || false
  cmp "$SANDBOX/dotfiles/ghostty.conf" <(printf 'font-size = 14\n')
}

@test "a read-only config is left alone, with instructions" {
  mkdir -p "$XDG"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  chmod 444 "$XDG/config.ghostty"
  run "$IGLASS" install --terminal ghostty
  assert_success_
  assert_output_has "Add these two lines"
  assert_output_has "$(include_line)"
  [[ "$(include_count "$XDG/config.ghostty")" == 0 ]] || false
  [[ -f "$XDG/themes/iglass-frosted-dark" ]] || false
  chmod 644 "$XDG/config.ghostty"
}

@test "real Liquid Glass on macOS 26+ when Ghostty supports it" {
  "$IGLASS" install --terminal ghostty
  grep -qx 'background-blur = macos-glass-clear' "$XDG/themes/iglass-clear-dark"
  grep -qx 'background-blur = macos-glass-regular' "$XDG/themes/iglass-frosted-light"
  grep -qx 'background-blur = false' "$XDG/themes/iglass-solid-dark"
  grep -qx 'background-opacity = 1' "$XDG/themes/iglass-solid-dark"
}

@test "falls back to blur on older macOS or an older Ghostty" {
  MOCK_MACOS=15.6 run "$IGLASS" install --terminal ghostty
  assert_output_has "(blur, "
  grep -qx 'background-blur = 24' "$XDG/themes/iglass-frosted-dark"

  MOCK_GHOSTTY_NO_GLASS=1 run "$IGLASS" install --terminal ghostty
  assert_success_
  assert_output_has "(blur, "
  run grep -rq "macos-glass" "$XDG/themes"
  [[ "$status" -eq 1 ]] || false
}

@test "--glass forces either mode" {
  "$IGLASS" install --terminal ghostty --glass blur
  grep -qx 'background-blur = 12' "$XDG/themes/iglass-clear-dark"
  MOCK_MACOS=15.6 "$IGLASS" install --terminal ghostty --glass native
  grep -qx 'background-blur = macos-glass-clear' "$XDG/themes/iglass-clear-dark"
  run "$IGLASS" install --terminal ghostty --glass shiny
  assert_failure_
  assert_output_has "Unknown glass mode"
}

@test "opacities follow the variants" {
  "$IGLASS" install --terminal ghostty
  grep -qx 'background-opacity = 0.5' "$XDG/themes/iglass-clear-dark"
  grep -qx 'background-opacity = 0.66' "$XDG/themes/iglass-frosted-dark"
  grep -qx 'background-opacity = 0.82' "$XDG/themes/iglass-tinted-light"
}

@test "custom opacity adds a custom theme pair; reinstalling without it removes them" {
  "$IGLASS" install --terminal ghostty --opacity 0.8 --variant clear
  grep -qx 'background-opacity = 0.8' "$XDG/themes/iglass-custom-dark"
  grep -qx 'background-blur = macos-glass-clear' "$XDG/themes/iglass-custom-dark"
  grep -qx 'theme = light:iglass-custom-light,dark:iglass-custom-dark' "$XDG/iglass.ghostty"
  "$IGLASS" install --terminal ghostty --blur 10
  grep -qx 'background-blur = 10' "$XDG/themes/iglass-custom-dark" # explicit radius wins
  "$IGLASS" install --terminal ghostty
  [[ ! -e "$XDG/themes/iglass-custom-dark" ]] || false
}

@test "cursor, window and font options map to Ghostty settings" {
  "$IGLASS" install --terminal ghostty --cursor box --window no-titlebar --font "Menlo-Regular 14"
  grep -qx 'cursor-style = block' "$XDG/iglass.ghostty"
  grep -qx 'macos-titlebar-style = hidden' "$XDG/iglass.ghostty"
  grep -qx 'font-family = "Mock Family"' "$XDG/iglass.ghostty"
  grep -qx 'font-size = 14' "$XDG/iglass.ghostty"
  "$IGLASS" install --terminal ghostty --cursor keep
  run grep -q '^cursor-style' "$XDG/iglass.ghostty"
  [[ "$status" -eq 1 ]] || false
}

@test "--appearance pins Ghostty to one theme; preview follows it" {
  "$IGLASS" install --terminal ghostty --appearance dark --variant tinted
  grep -qx 'theme = iglass-tinted-dark' "$XDG/iglass.ghostty"
  [[ -f "$XDG/themes/iglass-tinted-light" ]] || false # both still installed, for switching back
  run "$IGLASS" preview --terminal ghostty
  assert_logged "--theme=iglass-tinted-dark"
  run "$IGLASS" status
  assert_output_has "appearance dark"
  "$IGLASS" install --terminal ghostty --appearance light --opacity 0.8
  grep -qx 'theme = iglass-custom-light' "$XDG/iglass.ghostty"
  "$IGLASS" install --terminal ghostty
  grep -qx 'theme = light:iglass-frosted-light,dark:iglass-frosted-dark' "$XDG/iglass.ghostty"
}

@test "theme colors match the iTerm2 profile colors" {
  "$IGLASS" install --terminal ghostty --accent orange --contrast high
  local hex
  hex=$("$IGLASS" export --accent orange --contrast high | jq -r '
    .Profiles[1]["Ansi 1 Color (Light)"]
    | [."Red Component", ."Green Component", ."Blue Component"]
    | map(. * 255 | round) | map(if . < 16 then "0" else "" end + (. | tostring)) | join(",")')
  run grep '^palette = 1=' "$XDG/themes/iglass-frosted-light"
  local r g b
  IFS=, read -r r g b <<<"$hex"
  [[ "$output" == "$(printf 'palette = 1=#%02x%02x%02x' "$((10#$r))" "$((10#$g))" "$((10#$b))")" ]] || false
}

@test "every theme has 16 palette entries and well-formed colors" {
  "$IGLASS" install --terminal ghostty
  local f
  for f in "$XDG"/themes/*; do
    [[ $(grep -c '^palette = ' "$f") -eq 16 ]] || false
    if grep -E '^(background|foreground|cursor-color|selection-background) = ' "$f" |
      grep -vqE ' = #[0-9a-f]{6}$'; then
      echo "malformed color in $f" >&2
      return 1
    fi
  done
}

@test "a theme file the user made with an iglass- name is never deleted" {
  mkdir -p "$XDG/themes"
  printf 'background = #000000\n' >"$XDG/themes/iglass-mine"
  "$IGLASS" install --terminal ghostty
  "$IGLASS" uninstall --terminal ghostty
  [[ -f "$XDG/themes/iglass-mine" ]] || false
}

@test "nothing changes when Ghostty rejects the generated files" {
  mkdir -p "$XDG"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  MOCK_GHOSTTY_REJECT=1 run "$IGLASS" install --terminal ghostty
  assert_failure_
  assert_output_has "Nothing was changed"
  [[ ! -e "$XDG/themes" && ! -e "$XDG/iglass.ghostty" ]] || false
  cmp "$XDG/config.ghostty" <(printf 'font-size = 14\n')
}

@test "Ghostty must be installed to install for it" {
  export IGLASS_GHOSTTY_APP="$SANDBOX/missing.app"
  run "$IGLASS" install --terminal ghostty
  assert_failure_
  assert_output_has "Ghostty is not installed"
}

@test "running inside Ghostty installs for Ghostty by default" {
  TERM_PROGRAM=ghostty run "$IGLASS" install
  assert_success_
  [[ -f "$XDG/iglass.ghostty" && ! -e "$(profile_file)" ]] || false
}

@test "--terminal all installs both; plain uninstall removes both" {
  run "$IGLASS" install --terminal all
  assert_success_
  [[ -f "$XDG/iglass.ghostty" && -f "$(profile_file)" ]] || false
  run "$IGLASS" uninstall
  assert_success_
  [[ ! -e "$XDG/iglass.ghostty" && ! -e "$(profile_file)" ]] || false
}

@test "--app-settings is refused for Ghostty alone" {
  run "$IGLASS" install --terminal ghostty --app-settings
  assert_failure_
  assert_output_has "iTerm2 settings"
}

@test "export writes Ghostty files to a folder, and needs one" {
  run "$IGLASS" export --terminal ghostty --dir "$SANDBOX/out"
  assert_success_
  [[ -f "$SANDBOX/out/iglass.ghostty" && -f "$SANDBOX/out/themes/iglass-tinted-dark" ]] || false
  [[ ! -e "$XDG" ]] || false
  run "$IGLASS" export --terminal ghostty
  assert_failure_
  assert_output_has "--dir"
}

@test "preview opens Ghostty with the variant's themes" {
  run "$IGLASS" preview --terminal ghostty
  assert_failure_
  assert_output_has "not installed for Ghostty"
  "$IGLASS" install --terminal ghostty --variant tinted
  run "$IGLASS" preview --terminal ghostty
  assert_success_
  assert_logged "--theme=light:iglass-tinted-light,dark:iglass-tinted-dark"
  run "$IGLASS" preview --terminal ghostty --variant mist
  assert_failure_
}

@test "status and doctor report the Ghostty install" {
  "$IGLASS" install --terminal ghostty --accent green
  run "$IGLASS" status
  assert_output_has "accent green"
  assert_output_has "real Liquid Glass"
  run "$IGLASS" doctor
  assert_success_
  assert_output_has "Included from $XDG/config.ghostty"
}

@test "doctor notices a removed include and a later config overriding iglass" {
  "$IGLASS" install --terminal ghostty
  mkdir -p "$AS"
  printf 'theme = Dracula\n' >"$AS/config"
  run "$IGLASS" doctor
  assert_output_has "loads after"
  printf 'font-size = 14\n' >"$XDG/config.ghostty"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "doesn't include iglass"
}

@test "generated files pass the real Ghostty validator (skipped without Ghostty)" {
  local real=/Applications/Ghostty.app/Contents/MacOS/ghostty
  [[ -x "$real" ]] || skip "Ghostty is not installed"
  local accent contrast glass out home
  for glass in native blur; do
    for contrast in standard high; do
      for accent in blue graphite; do
        out="$SANDBOX/real-$glass-$contrast-$accent"
        "$IGLASS" export --terminal ghostty --glass "$glass" --contrast "$contrast" \
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
