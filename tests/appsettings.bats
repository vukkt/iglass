#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031  # per-test exports are meant to stay inside each test
# App-wide settings: apply, exact restore, and the restart-iTerm2 flow (all sandboxed).

load helpers

setup() {
  setup_sandbox
  defaults write "$IGLASS_PREFS_DOMAIN" TabStyleWithAutomaticOption -int 1
  defaults write "$IGLASS_PREFS_DOMAIN" "Default Bookmark Guid" -string USER-DEFAULT
}

@test "with iTerm2 closed, settings apply immediately" {
  run "$IGLASS" install --app-settings
  assert_success_
  [[ "$(pref TabStyleWithAutomaticOption)" == 5 ]]
  [[ "$(pref TerminalMargin)" == 12 ]]
  [[ "$(pref TerminalVMargin)" == 10 ]]
  [[ "$(pref 'Default Bookmark Guid')" == USER-DEFAULT ]]
  refute_logged "launchctl submit"
  run "$IGLASS" status
  assert_output_has "App-wide settings applied"
}

@test "uninstall restores exactly: old values back, new keys removed" {
  "$IGLASS" install --app-settings --default
  "$IGLASS" uninstall --restore-app-settings
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
  [[ "$(pref 'Default Bookmark Guid')" == USER-DEFAULT ]]
  [[ "$(pref TerminalMargin)" == "<absent>" ]]
  [[ "$(pref TerminalVMargin)" == "<absent>" ]]
  run jq -r '.appSettings // "none"' "$(state_file)"
  [[ "$output" == none ]]
}

@test "restored values keep their original types" {
  "$IGLASS" install --app-settings
  "$IGLASS" uninstall --restore-app-settings
  run defaults read-type "$IGLASS_PREFS_DOMAIN" TabStyleWithAutomaticOption
  [[ "$output" == "Type is integer" ]]
}

@test "re-applying never overwrites the recorded originals" {
  "$IGLASS" install --app-settings
  "$IGLASS" install --app-settings --default
  run jq -r '.appSettings.previous.TabStyleWithAutomaticOption.value,
             .appSettings.previous["Default Bookmark Guid"].value' "$(state_file)"
  [[ "$output" == $'1\nUSER-DEFAULT' ]]
}

@test "--default points at the chosen variant, or the custom profile" {
  local tinted custom
  tinted=$(jq -r '.variants.tinted.guid' "$REPO_ROOT/data/palette.json")
  custom=$(jq -r '.custom.guid' "$REPO_ROOT/data/palette.json")
  "$IGLASS" install --variant tinted --default
  [[ "$(pref 'Default Bookmark Guid')" == "$tinted" ]]
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]] # --default alone leaves the theme
  "$IGLASS" install --variant tinted --opacity 0.9 --default
  [[ "$(pref 'Default Bookmark Guid')" == "$custom" ]]
}

@test "the first backup, taken before any change, is kept" {
  "$IGLASS" install --app-settings
  "$IGLASS" install --app-settings
  local first="$IGLASS_STATE_DIR/backups/iterm2-prefs-before-iglass.plist"
  [[ -f "$first" ]]
  run plutil -extract TabStyleWithAutomaticOption raw -o - "$first"
  [[ "$output" == 1 ]]
  run ls "$IGLASS_STATE_DIR/backups"
  [[ $(wc -l <<<"$output") -eq 2 ]]
}

@test "iTerm2 running and no terminal to ask: refuses and changes nothing" {
  iterm_start
  run "$IGLASS" install --app-settings </dev/null
  assert_failure_
  assert_output_has "Nothing changed"
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
  refute_logged "launchctl submit"
}

@test "iTerm2 running with --yes: quits it via launchd, applies, reopens it" {
  iterm_start
  run "$IGLASS" install --app-settings --yes
  assert_success_
  assert_output_has "quit and reopen"
  assert_logged "launchctl submit com.github.vukkt.iglass.apply."
  assert_logged "osascript quit"
  assert_logged "open -b com.googlecode.iterm2"
  assert_logged "launchctl remove com.github.vukkt.iglass.apply."
  [[ "$(pref TabStyleWithAutomaticOption)" == 5 ]]
  run "$IGLASS" status
  assert_output_has "App-wide settings applied"
}

@test "if iTerm2 won't quit, nothing is written and status says so" {
  iterm_start
  export MOCK_QUIT_REFUSE=1 IGLASS_APPLY_TIMEOUT=1
  run "$IGLASS" install --app-settings --yes
  assert_success_ # the helper runs in the background; the CLI reports later
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
  assert_logged "osascript notify"
  refute_logged "open -b"
  run "$IGLASS" status
  assert_output_has "not applied"
}

@test "a cancelled restore keeps the originals so it can be retried" {
  "$IGLASS" install --app-settings
  iterm_start
  export MOCK_QUIT_REFUSE=1 IGLASS_APPLY_TIMEOUT=1
  "$IGLASS" uninstall --restore-app-settings --yes
  [[ "$(pref TabStyleWithAutomaticOption)" == 5 ]]
  run jq -r '.appSettings.previous.TabStyleWithAutomaticOption.value' "$(state_file)"
  [[ "$output" == 1 ]]

  unset MOCK_QUIT_REFUSE
  iterm_stop
  run "$IGLASS" uninstall --restore-app-settings
  assert_success_
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
}

@test "uninstall --keep-app-settings leaves preferences alone" {
  "$IGLASS" install --app-settings --default
  run "$IGLASS" uninstall --keep-app-settings
  assert_success_
  assert_output_has "Kept iTerm2's app-wide settings"
  assert_output_has "pick a new default"
  [[ "$(pref TabStyleWithAutomaticOption)" == 5 ]]
}

@test "uninstall without a terminal to ask keeps settings (never guesses yes)" {
  "$IGLASS" install --app-settings
  run "$IGLASS" uninstall </dev/null
  assert_success_
  [[ "$(pref TabStyleWithAutomaticOption)" == 5 ]]
}

@test "refuses when iTerm2 loads preferences from a custom folder" {
  defaults write "$IGLASS_PREFS_DOMAIN" LoadPrefsFromCustomFolder -bool true
  run "$IGLASS" install --app-settings
  assert_failure_
  assert_output_has "custom folder"
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
}

@test "refuses to manage a key with an unexpected type" {
  defaults write "$IGLASS_PREFS_DOMAIN" TerminalMargin -array 1 2
  run "$IGLASS" install --app-settings
  assert_failure_
  assert_output_has "unexpected type"
  [[ "$(pref TabStyleWithAutomaticOption)" == 1 ]]
}

@test "a new change waits while a previous one is still pending" {
  iterm_start
  export MOCK_QUIT_REFUSE=1 IGLASS_APPLY_TIMEOUT=1
  # Simulate a helper that hasn't reported back yet.
  mkdir -p "$IGLASS_STATE_DIR"
  printf '{"appSettings":{"pending":{"op":"apply","id":"still-running"}}}' >"$(state_file)"
  run "$IGLASS" install --app-settings --yes
  assert_failure_
  assert_output_has "has not finished yet"
}
