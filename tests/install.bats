#!/usr/bin/env bats
# install / uninstall / preview / status / list against a sandboxed profiles folder.

load helpers

setup() { setup_sandbox; }

teardown() {
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
}

@test "install writes a valid profiles file and records state" {
  run "$IGLASS" install --accent orange
  assert_success_
  plutil -convert xml1 -o /dev/null "$(profile_file)"
  run jq -r '.options.accent + " " + .options.variant + " " + .version' "$(state_file)"
  [[ "$output" == "orange frosted 1.0.0" ]]
}

@test "install is idempotent: reinstalling gives a byte-identical file" {
  "$IGLASS" install --accent green --opacity 0.8
  cp "$(profile_file)" "$BATS_TEST_TMPDIR/first.json"
  "$IGLASS" install --accent green --opacity 0.8
  cmp "$(profile_file)" "$BATS_TEST_TMPDIR/first.json"
}

@test "install leaves no temporary files behind" {
  "$IGLASS" install
  run ls -A "$IGLASS_DYNPROFILES_DIR"
  [[ "$output" == iglass.json ]]
  run find "$IGLASS_STATE_DIR" -name '.*'
  [[ -z "$output" ]]
}

@test "install never touches other files in the profiles folder" {
  printf '{"Profiles":[{"Name":"Mine","Guid":"11111111-2222-3333-4444-555555555555"}]}' \
    >"$IGLASS_DYNPROFILES_DIR/mine.json"
  cp "$IGLASS_DYNPROFILES_DIR/mine.json" "$BATS_TEST_TMPDIR/mine.json"
  "$IGLASS" install
  "$IGLASS" uninstall
  cmp "$IGLASS_DYNPROFILES_DIR/mine.json" "$BATS_TEST_TMPDIR/mine.json"
}

@test "install creates the profiles folder when iTerm2 has never run" {
  rm -rf "$IGLASS_DYNPROFILES_DIR"
  run "$IGLASS" install
  assert_success_
  [[ -f "$(profile_file)" ]]
}

@test "install fails cleanly when the profiles folder is read-only" {
  chmod 555 "$IGLASS_DYNPROFILES_DIR"
  run "$IGLASS" install
  assert_failure_
  assert_output_has "No permission"
  [[ ! -e "$(profile_file)" ]]
}

@test "install keeps the previous file if writing fails" {
  "$IGLASS" install --accent purple
  cp "$(profile_file)" "$BATS_TEST_TMPDIR/before.json"
  chmod 555 "$IGLASS_DYNPROFILES_DIR"
  run "$IGLASS" install --accent red
  assert_failure_
  cmp "$(profile_file)" "$BATS_TEST_TMPDIR/before.json"
}

@test "install warns but proceeds when iTerm2 is missing or old" {
  rm -rf "$IGLASS_ITERM_APP"
  run "$IGLASS" install
  assert_success_
  assert_output_has "doesn't seem to be installed"

  fake_iterm_version 3.4.20
  run "$IGLASS" install
  assert_success_
  assert_output_has "older than 3.5.0"
}

@test "status reflects what is installed" {
  run "$IGLASS" status
  assert_success_
  assert_output_has "Not installed"
  "$IGLASS" install --accent pink --cursor box --opacity 0.9
  run "$IGLASS" status
  assert_success_
  assert_output_has "accent pink"
  assert_output_has "cursor box"
  assert_output_has "custom profile: transparency=0.1"
}

@test "list marks the installed variant and accent" {
  "$IGLASS" install --variant tinted --accent graphite
  run "$IGLASS" list
  assert_success_
  [[ "$output" == *"tinted"*"(selected)"* ]]
  assert_output_has "graphite (installed)"
}

@test "uninstall removes the profiles and is safe to repeat" {
  "$IGLASS" install
  run "$IGLASS" uninstall
  assert_success_
  [[ ! -e "$(profile_file)" ]]
  run "$IGLASS" uninstall
  assert_success_
  assert_output_has "were not installed"
}

@test "uninstall leaves a foreign iglass.json alone" {
  printf '{"Profiles":[{"Name":"Someone else","Guid":"AAAAAAAA-0000-0000-0000-000000000000"}]}' \
    >"$(profile_file)"
  run "$IGLASS" uninstall
  assert_success_
  assert_output_has "isn't an iglass file"
  [[ -f "$(profile_file)" ]]
}

@test "preview needs an installation" {
  run "$IGLASS" preview
  assert_failure_
  assert_output_has "not installed"
}

@test "preview opens the selected variant by name" {
  "$IGLASS" install --variant clear
  run "$IGLASS" preview
  assert_success_
  assert_logged "osascript create-window iglass Clear"
  run "$IGLASS" preview --variant solid
  assert_success_
  assert_logged "osascript create-window iglass Solid"
}

@test "preview defaults to the custom profile when one was made" {
  "$IGLASS" install --opacity 0.85
  run "$IGLASS" preview
  assert_success_
  assert_logged "osascript create-window iglass Custom"
}

@test "preview rejects a custom profile that isn't installed and unknown variants" {
  "$IGLASS" install
  run "$IGLASS" preview --variant custom
  assert_failure_
  assert_output_has "No custom profile"
  run "$IGLASS" preview --variant mist
  assert_failure_
  assert_output_has "Unknown variant"
}

@test "preview reports when iTerm2 can't open the profile" {
  "$IGLASS" install
  MOCK_WINDOW_FAIL=1 run "$IGLASS" preview
  assert_failure_
  assert_output_has "could not open"
}
