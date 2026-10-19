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

case "$(uname -s)" in
  Darwin) os=macos ;;
  Linux) os=linux ;;
  *) fail "iglass supports macOS and Linux." ;;
esac

if [[ $action == uninstall ]]; then
  if [[ -L "$bin/iglass" ]]; then rm -f "$bin/iglass"; fi
  rm -rf "$share"
  say "Removed the iglass command."
  say "If the theme is still installed, run \`iglass uninstall\` before this next time. Its files stay"
  say "until you delete them:"
  if [[ $os == macos ]]; then
    say "  $HOME/Library/Application Support/iTerm2/DynamicProfiles/iglass.json"
  fi
  say "  ${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/iglass.ghostty and themes/iglass-*"
  say "  ${XDG_CONFIG_HOME:-$HOME/.config}/kitty/iglass.conf and *-theme.auto.conf (and the include in kitty.conf)"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  [[ $os == macos ]] && fail "jq not found. iglass needs macOS 15 or later (it includes /usr/bin/jq)."
  # The distribution's own package manager, from ID and ID_LIKE (Garuda, CachyOS and Manjaro are Arch-like).
  ids=" $(sed -n -e 's/^ID=//p' -e 's/^ID_LIKE=//p' "${IGLASS_OS_RELEASE:-/etc/os-release}" 2>/dev/null | tr -d '"' | tr '\n' ' ') "
  case "$ids" in
    *" arch "*) fail "iglass needs jq. Install it with: sudo pacman -S jq" ;;
    *" debian "* | *" ubuntu "*) fail "iglass needs jq. Install it with: sudo apt install jq" ;;
    *" fedora "* | *" rhel "*) fail "iglass needs jq. Install it with: sudo dnf install jq" ;;
    *suse*) fail "iglass needs jq. Install it with: sudo zypper install jq" ;;
  esac
  fail "iglass needs jq. Install it with your package manager, e.g. sudo apt install jq (or dnf, pacman, zypper)."
fi
command -v curl >/dev/null 2>&1 || [[ -n "$local_src" ]] || fail "curl not found."

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
    case "${SHELL:-}" in
      */bash) rc=.bashrc ;;
      */fish) rc="" ;;
      *) rc=.zshrc ;;
    esac
    if [[ -n "$rc" ]]; then
      say "Add $bin to your PATH, e.g.:"
      say "  echo 'export PATH=\"$bin:\$PATH\"' >> ~/$rc && source ~/$rc"
    else
      say "Add $bin to your PATH:"
      say "  fish_add_path $bin"
    fi
    say "Then: iglass install"
    ;;
esac
