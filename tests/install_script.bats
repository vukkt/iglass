#!/usr/bin/env bats
# install.sh, exercised with --local into a temporary prefix (no network).

load helpers

setup() {
  setup_sandbox
  PREFIX="$SANDBOX/prefix"
}

@test "installs the command and it runs through the symlink" {
  run "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  assert_success_
  [[ -L "$PREFIX/bin/iglass" ]]
  run "$PREFIX/bin/iglass" --version
  assert_success_
  [[ "$output" == "$("$IGLASS" --version)" ]]
  run "$PREFIX/bin/iglass" export
  assert_success_
}

@test "the installed copy carries only what it needs at runtime" {
  "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  run ls "$PREFIX/share/iglass"
  [[ "$output" == $'LICENSE\nbin\ndata\nlib' || "$output" == $'bin\ndata\nlib' ]]
}

@test "reinstalling replaces the previous copy cleanly" {
  "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  touch "$PREFIX/share/iglass/stale-file"
  run "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  assert_success_
  [[ ! -e "$PREFIX/share/iglass/stale-file" ]]
  run find "$PREFIX/share" -maxdepth 1 -name '.iglass.*'
  [[ -z "$output" ]]
}

@test "--uninstall removes the command and its files" {
  "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  run "$REPO_ROOT/install.sh" --uninstall --prefix "$PREFIX"
  assert_success_
  [[ ! -e "$PREFIX/bin/iglass" && ! -e "$PREFIX/share/iglass" ]]
}

@test "refuses an incomplete package and leaves the old install alone" {
  "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  local broken="$SANDBOX/broken"
  mkdir -p "$broken"
  cp -R "$REPO_ROOT/bin" "$REPO_ROOT/lib" "$REPO_ROOT/install.sh" "$broken/"
  run "$broken/install.sh" --local --prefix "$PREFIX"
  assert_failure_
  assert_output_has "data/palette.json is missing"
  [[ -f "$PREFIX/share/iglass/data/palette.json" ]]
}

@test "tells the user how to add the bin folder to PATH" {
  run "$REPO_ROOT/install.sh" --local --prefix "$PREFIX"
  assert_output_has "Add $PREFIX/bin to your PATH"
}

@test "rejects unknown options" {
  run "$REPO_ROOT/install.sh" --sparkle
  assert_failure_
}
