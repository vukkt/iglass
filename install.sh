#!/bin/bash
# Installs the iglass command (not the theme itself; run `iglass install` afterwards).
#
#   curl -fsSL https://raw.githubusercontent.com/vukkt/iglass/main/install.sh | bash
#
# Options:
#   --version X.Y.Z   install a specific release (default: latest)
#   --prefix DIR      install under DIR (default: ~/.local) → DIR/share/iglass, DIR/bin/iglass
#   --local           install from the folder this script is in (a git checkout)
#   --uninstall       remove the iglass command (run `iglass uninstall` first to remove the theme)

set -euo pipefail

REPO="vukkt/iglass"
prefix="$HOME/.local"
version=""
local_src=""
action=install

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version=${2:?--version needs a value}; shift 2 ;;
    --prefix) prefix=${2:?--prefix needs a value}; shift 2 ;;
    --local) local_src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); shift ;;
    --uninstall) action=uninstall; shift ;;
    -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 1 ;;
  esac
done

share="$prefix/share/iglass"
bin="$prefix/bin"

say() { printf '%s\n' "$*"; }
fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

if [[ $action == uninstall ]]; then
  if [[ -L "$bin/iglass" ]]; then rm -f "$bin/iglass"; fi
  rm -rf "$share"
  say "Removed the iglass command."
  say "If the theme is still installed, its profiles stay until you delete"
  say "$HOME/Library/Application Support/iTerm2/DynamicProfiles/iglass.json"
  exit 0
fi

[[ "$(uname -s)" == Darwin ]] || fail "iglass is for macOS."
command -v jq >/dev/null 2>&1 || fail "jq not found. iglass needs macOS 15 or later (it includes /usr/bin/jq)."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ -n "$local_src" ]]; then
  src="$local_src"
else
  if [[ -z "$version" ]]; then
    version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
      jq -r '.tag_name // empty' | sed 's/^v//') || true
    [[ -n "$version" ]] || fail "could not find the latest release of $REPO."
  fi
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "not a version: $version"
  say "Downloading iglass ${version}..."
  curl -fsSL "https://github.com/$REPO/archive/refs/tags/v$version.tar.gz" -o "$work/iglass.tar.gz" ||
    fail "download failed."
  tar -xzf "$work/iglass.tar.gz" -C "$work"
  src="$work/iglass-$version"
fi

for f in bin/iglass lib/profile.jq lib/apply-helper.sh data/palette.json; do
  [[ -f "$src/$f" ]] || fail "incomplete package: $f is missing."
done

# Stage next to the destination, then swap it in, so a failed copy never leaves half an install.
mkdir -p "$prefix/share" "$bin"
stage=$(mktemp -d "$prefix/share/.iglass.XXXXXX")
cp -R "$src/bin" "$src/lib" "$src/data" "$stage/"
[[ -f "$src/LICENSE" ]] && cp "$src/LICENSE" "$stage/"
rm -rf "$share"
mv "$stage" "$share"
ln -sfn "$share/bin/iglass" "$bin/iglass"

say "Installed $("$bin/iglass" --version) to $share"
case ":$PATH:" in
  *":$bin:"*) say "Next: iglass install" ;;
  *)
    say "Add $bin to your PATH, e.g. for zsh:"
    say "  echo 'export PATH=\"$bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    say "Then: iglass install"
    ;;
esac
