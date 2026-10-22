#!/usr/bin/env bats
# bats file_tags=macos
# iglass doctor: read-only checks with a clear verdict.

load helpers

setup() { setup_sandbox; }

@test "healthy setup passes" {
  "$IGLASS" install
  run "$IGLASS" doctor
  assert_success_
  assert_output_has "No problems found"
}

@test "doctor changes nothing" {
  "$IGLASS" install
  local before after
  before=$(find "$SANDBOX" -type f -not -name calls.log -exec shasum {} + | sort)
  "$IGLASS" doctor
  after=$(find "$SANDBOX" -type f -not -name calls.log -exec shasum {} + | sort)
  [[ "$before" == "$after" ]] || false
}

@test "finds another broken file that would block every dynamic profile" {
  "$IGLASS" install
  printf '{"Profiles": [' >"$IGLASS_DYNPROFILES_DIR/broken.json"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "Unreadable profile file"
  assert_output_has "broken.json"
}

@test "reads other people's XML plists without complaint" {
  "$IGLASS" install
  cat >"$IGLASS_DYNPROFILES_DIR/other.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>Profiles</key><array/></dict></plist>
EOF
  run "$IGLASS" doctor
  assert_success_
}

@test "flags a second copy of iglass profiles" {
  "$IGLASS" install
  cp "$IGLASS_DYNPROFILES_DIR/iglass.json" "$IGLASS_DYNPROFILES_DIR/iglass-copy.json"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "reuses iglass profile IDs"
}

@test "flags a damaged iglass file" {
  "$IGLASS" install
  local guid
  guid=$(jq -r '.variants.frosted.guid' "$REPO_ROOT/data/palette.json")
  printf '{"Profiles": [{"Guid": "%s"}]}' "$guid" >"$IGLASS_DYNPROFILES_DIR/iglass.json"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "damaged"
}

@test "flags iTerm2 that is missing or too old" {
  rm -rf "$IGLASS_ITERM_APP"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "not installed"
  fake_iterm_version 3.4.9
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "older than 3.5.0"
}

@test "flags a macOS that is too old" {
  MOCK_MACOS=14.6 run "$IGLASS" doctor
  assert_failure_
  assert_output_has "macOS 14.6 is older"
}

@test "flags a font that disappeared after install" {
  "$IGLASS" install --font Menlo-Regular
  MOCK_MISSING_FONTS=Menlo-Regular run "$IGLASS" doctor
  assert_failure_
  assert_output_has "Font Menlo-Regular is not installed"
}

@test "reports a failed settings change" {
  mkdir -p "$IGLASS_STATE_DIR"
  printf '{"appSettings":{"status":"failed","lastError":"could not write: X"}}' >"$(state_file)"
  run "$IGLASS" doctor
  assert_failure_
  assert_output_has "could not write: X"
}
