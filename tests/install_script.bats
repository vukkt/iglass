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
  # A fixed collation: some locales sort LICENSE after bin.
  run env LC_ALL=C ls "$PREFIX/share/iglass"
  [[ "$output" == $'LICENSE\nbin\ndata\nlib' ]]
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

# The download path, with a stand-in curl serving a tarball shaped like GitHub's archive.
fake_github() {
  local version=$1
  mkdir -p "$SANDBOX/served"
  git -C "$REPO_ROOT" archive --format=tar.gz --prefix="iglass-$version/" HEAD \
    -o "$SANDBOX/served/v$version.tar.gz"
  cat >"$MOCK_DIR/bin/curl" <<CURL
#!/bin/bash
out=""
url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) out=\$2; shift 2 ;;
    -*) shift ;;
    *) url=\$1; shift ;;
  esac
done
echo "curl \$url" >>"\$MOCK_LOG"
case "\$url" in
  *api.github.com*/releases/latest) printf '{"tag_name":"v$version"}' ;;
  *archive/refs/tags/v$version.tar.gz) cp "$SANDBOX/served/v$version.tar.gz" "\$out" ;;
  *) exit 22 ;;
esac
CURL
  chmod +x "$MOCK_DIR/bin/curl"
}

@test "downloads and installs the latest release" {
  fake_github 1.0.0
  run "$REPO_ROOT/install.sh" --prefix "$PREFIX"
  assert_success_
  assert_output_has "Downloading iglass 1.0.0"
  assert_logged "releases/latest"
  assert_logged "archive/refs/tags/v1.0.0.tar.gz"
  run "$PREFIX/bin/iglass" export
  assert_success_
}

@test "installs a requested version and rejects malformed ones" {
  fake_github 1.0.0
  run "$REPO_ROOT/install.sh" --version 1.0.0 --prefix "$PREFIX"
  assert_success_
  refute_logged "releases/latest"
  run "$REPO_ROOT/install.sh" --version 'v1;rm' --prefix "$PREFIX"
  assert_failure_
  assert_output_has "not a version"
}

@test "a failed download leaves no install behind" {
  fake_github 1.0.0
  run "$REPO_ROOT/install.sh" --version 9.9.9 --prefix "$PREFIX"
  assert_failure_
  assert_output_has "download failed"
  [[ ! -e "$PREFIX/bin/iglass" ]]
}

@test "no shell file puts a non-ASCII character right after a variable" {
  # bash 3.2 reads such bytes as part of the name: "$version…" looks up "version…".
  run env LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~[:space:]]' \
    "$REPO_ROOT/bin/iglass" "$REPO_ROOT"/lib/*.sh "$REPO_ROOT/install.sh" "$REPO_ROOT"/tools/*.sh
  [[ "$status" -eq 1 ]] || { echo "$output" >&2; return 1; }
}
