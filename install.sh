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
#
# Tab completion for bash, zsh and fish is linked into DIR/share, where bash-completion and fish
# find it on their own; zsh needs DIR/share/zsh/site-functions in its fpath (install says how).

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
    -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 1 ;;
  esac
done

share="$prefix/share/iglass"
bin="$prefix/bin"
# Where each shell looks for completions under a prefix, and the file iglass ships for it.
completion_links="bash-completion/completions/iglass:iglass.bash
zsh/site-functions/_iglass:_iglass
fish/vendor_completions.d/iglass.fish:iglass.fish"

say() { printf '%s\n' "$*"; }
fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin) os=macos ;;
  Linux) os=linux ;;
  *) fail "iglass supports macOS and Linux." ;;
esac

# remove_completions — remove the completion links that point into this install.
remove_completions() {
  local entry link
  while IFS= read -r entry; do
    link="$prefix/share/${entry%%:*}"
    if [[ -L "$link" && "$(readlink "$link")" == "$share/"* ]]; then rm -f "$link"; fi
  done <<<"$completion_links"
}

if [[ $action == uninstall ]]; then
  if [[ -L "$bin/iglass" ]]; then rm -f "$bin/iglass"; fi
  remove_completions
  rm -rf "$share"
  say "Removed the iglass command."
  say "If the theme is still installed, run \`iglass uninstall\` before this next time. Its files stay"
  say "until you delete them:"
  if [[ $os == macos ]]; then
    say "  $HOME/Library/Application Support/iTerm2/DynamicProfiles/iglass.json"
  fi
  say "  ${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/iglass.ghostty and themes/iglass-*"
  say "  ${XDG_CONFIG_HOME:-$HOME/.config}/kitty/iglass.conf and *-theme.auto.conf (and the include in kitty.conf)"
  if [[ $os == macos ]]; then
    say "  $HOME/.warp/themes/iglass-*.yaml (and iglass's settings in ~/.warp/settings.toml)"
  else
    say "  ${XDG_DATA_HOME:-$HOME/.local/share}/warp-terminal/themes/iglass-*.yaml (and iglass's settings in Warp's settings.toml)"
  fi
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
stage=""
trap 'rm -rf "$work" ${stage:+"$stage"}' EXIT

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
[[ -d "$src/completions" ]] && cp -R "$src/completions" "$stage/" # releases since 1.7.0
rm -rf "$share"
mv "$stage" "$share"
stage=""
ln -sfn "$share/bin/iglass" "$bin/iglass"

# Tab completion: links into this install, so updates keep them current. A file there that
# isn't iglass's is left alone.
remove_completions
if [[ -d "$share/completions" ]]; then
  while IFS= read -r entry; do
    link="$prefix/share/${entry%%:*}"
    if [[ -e "$link" || -L "$link" ]]; then
      say "Tab completion: $link already exists and isn't iglass's; left it alone."
    elif ! { mkdir -p "$(dirname "$link")" && ln -s "$share/completions/${entry#*:}" "$link"; } 2>/dev/null; then
      say "Tab completion: couldn't write to $(dirname "$link"); skipped."
    fi
  done <<<"$completion_links"
fi

say "Installed $("$bin/iglass" --version) to $share"
if [[ "${SHELL:-}" == */zsh && -d "$share/completions" ]]; then
  case "$prefix" in
    /usr/local | /usr) ;; # already in zsh's fpath
    *)
      say "For tab completion in zsh, add this to ~/.zshrc, before compinit runs (or oh-my-zsh loads):"
      say "  fpath=(\"$prefix/share/zsh/site-functions\" \$fpath)"
      ;;
  esac
fi
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
