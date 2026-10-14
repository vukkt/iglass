#!/usr/bin/env bats
# bats file_tags=macos
# Command-line interface: help, versions, option parsing and validation.

load helpers

setup() { setup_sandbox; }

@test "--version prints the version" {
  run "$IGLASS" --version
  assert_success_
  [[ "$output" =~ ^iglass\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "no arguments prints usage" {
  run "$IGLASS"
  assert_success_
  assert_output_has "Usage"
}

@test "--help works after a command too" {
  run "$IGLASS" install --help
  assert_success_
  assert_output_has "Look options"
  [[ ! -f "$(profile_file)" ]]
}

@test "unknown command fails with a hint" {
  run "$IGLASS" frobnicate
  assert_failure_
  assert_output_has "Unknown command: frobnicate"
}

@test "unknown option fails" {
  run "$IGLASS" install --sparkle
  assert_failure_
  assert_output_has "Unknown option: --sparkle"
}

@test "an option missing its value fails" {
  run "$IGLASS" install --accent
  assert_failure_
  assert_output_has "--accent needs a value"
  run "$IGLASS" install --accent --force
  assert_failure_
  assert_output_has "--accent needs a value"
}

@test "invalid variant, accent, cursor and window are rejected" {
  run "$IGLASS" install --variant smoky
  assert_failure_
  assert_output_has "Unknown variant: smoky"
  run "$IGLASS" install --accent teal
  assert_failure_
  assert_output_has "Unknown accent: teal"
  run "$IGLASS" install --cursor blob
  assert_failure_
  assert_output_has "Unknown cursor style"
  run "$IGLASS" install --window round
  assert_failure_
  assert_output_has "Unknown window style"
  [[ ! -f "$(profile_file)" ]]
}

@test "--opacity rejects non-numbers and out-of-range values" {
  for bad in abc 1.5 -0.3 0.01 0 2 "0.5x"; do
    run "$IGLASS" install --opacity "$bad"
    assert_failure_
  done
  [[ ! -f "$(profile_file)" ]]
}

@test "--opacity below the readable minimum needs --force" {
  run "$IGLASS" install --opacity 0.5
  assert_failure_
  assert_output_has "--force"
  [[ ! -f "$(profile_file)" ]]

  run "$IGLASS" install --opacity 0.5 --force
  assert_success_
  assert_output_has "may be hard to read"
}

@test "--opacity accepts a leading-dot value" {
  run "$IGLASS" install --opacity .9
  assert_success_
  run jq -r '.Profiles[] | select(.Name == "iglass Custom") | .Transparency' "$(profile_file)"
  [[ "$output" == 0.1 ]]
}

@test "--blur validates range and warns when high" {
  for bad in 65 -1 x 2.5; do
    run "$IGLASS" install --blur "$bad"
    assert_failure_
  done
  run "$IGLASS" install --blur 30
  assert_success_
  assert_output_has "slow"
}

@test "--blur 0 turns blur off in the custom profile" {
  run "$IGLASS" install --blur 0
  assert_success_
  run jq -r '.Profiles[] | select(.Name == "iglass Custom") | "\(.Blur) \(."Blur Radius")"' "$(profile_file)"
  [[ "$output" == "false 0" ]]
}

@test "--font sets the font when it is installed" {
  run "$IGLASS" install --font "Menlo-Regular 14"
  assert_success_
  run jq -r '[.Profiles[]."Normal Font"] | unique | .[]' "$(profile_file)"
  [[ "$output" == "Menlo-Regular 14" ]]
}

@test "--font without a size defaults to 13" {
  run "$IGLASS" install --font Menlo-Regular
  assert_success_
  run jq -r '.Profiles[0]."Normal Font"' "$(profile_file)"
  [[ "$output" == "Menlo-Regular 13" ]]
}

@test "--font rejects missing fonts with a helpful message" {
  export MOCK_MISSING_FONTS="SFMono-Regular NoSuchFont"
  run "$IGLASS" install --font sf-mono
  assert_failure_
  assert_output_has "developer.apple.com/fonts"
  run "$IGLASS" install --font NoSuchFont
  assert_failure_
  assert_output_has "not installed"
  [[ ! -f "$(profile_file)" ]]
}

@test "--font rejects display names with spaces and bad sizes" {
  run "$IGLASS" install --font "JetBrains Mono"
  assert_failure_
  assert_output_has "PostScript name"
  run "$IGLASS" install --font "Menlo-Regular 200"
  assert_failure_
  assert_output_has "size"
}

@test "--app-settings is refused outside install" {
  run "$IGLASS" export --app-settings
  assert_failure_
  assert_output_has "only works with iglass install"
}

@test "export prints a valid profiles document and writes nothing" {
  run "$IGLASS" export --accent green
  assert_success_
  [[ ! -e "$(profile_file)" && ! -e "$IGLASS_STATE_DIR" ]]
  printf '%s\n' "$output" >"$BATS_TEST_TMPDIR/out.json"
  plutil -convert xml1 -o /dev/null "$BATS_TEST_TMPDIR/out.json"
  run jq -r '.Profiles | length' "$BATS_TEST_TMPDIR/out.json"
  [[ "$output" == 4 ]]
}

@test "commands fail cleanly when the color data is missing" {
  IGLASS_PALETTE="$SANDBOX/nope.json" run "$IGLASS" install
  assert_failure_
  assert_output_has "Color data not found"
}
