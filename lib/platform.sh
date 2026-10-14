# shellcheck shell=bash
# The few things that differ between macOS and Linux.
#
# IGLASS_PLATFORM (macos or linux) decides what iglass does: which terminals, paths and
# settings. It can be set to run the other platform's code paths, which is how the test suite
# covers both on one machine. The flavor of system tools (BSD or GNU stat, pgrep) always
# follows the machine iglass actually runs on.

case "$(uname -s)" in
  Linux) IGLASS_HOST_OS=linux ;;
  *) IGLASS_HOST_OS=macos ;;
esac
IGLASS_PLATFORM=${IGLASS_PLATFORM:-$IGLASS_HOST_OS}
[[ "$IGLASS_PLATFORM" == macos || "$IGLASS_PLATFORM" == linux ]] ||
  die "IGLASS_PLATFORM must be macos or linux (got $IGLASS_PLATFORM)."

is_macos() { [[ "$IGLASS_PLATFORM" == macos ]]; }
is_linux() { [[ "$IGLASS_PLATFORM" == linux ]]; }

# file_mode FILE — permission bits, e.g. 644. Chosen by OS, not by trying one and then the
# other: GNU `stat -f` means "file system status" and succeeds with unrelated output.
file_mode() {
  if [[ $IGLASS_HOST_OS == macos ]]; then
    stat -f %Lp "$1" 2>/dev/null
  else
    stat -c %a "$1" 2>/dev/null
  fi
}

# proc_running NAME — true when a process with exactly this name runs. macOS pgrep leaves out
# its own ancestors unless given -a, and iglass usually runs inside the terminal it checks for.
# Linux pgrep has no such filter, and there -a means something else (print the command line).
proc_running() {
  if [[ $IGLASS_HOST_OS == macos ]]; then
    pgrep -a -x "$1" >/dev/null 2>&1
  else
    pgrep -x "$1" >/dev/null 2>&1
  fi
}

# The OS name and version, e.g. "macOS 27.0.1" or "Fedora Linux 43".
os_description() {
  if is_macos; then
    printf 'macOS %s\n' "$(macos_version)"
    return
  fi
  local file=${IGLASS_OS_RELEASE:-/etc/os-release} name="" version=""
  if [[ -r "$file" ]]; then
    name=$(sed -n 's/^NAME=//p' "$file" | head -n 1 | tr -d '"')
    version=$(sed -n 's/^VERSION_ID=//p' "$file" | head -n 1 | tr -d '"')
  fi
  printf '%s\n' "${name:-Linux}${version:+ $version}"
}

macos_version() {
  is_macos || return 0
  sw_vers -productVersion 2>/dev/null || true
}

# detach CMD… — start a GUI program that outlives iglass, with its output discarded.
detach() {
  if command -v setsid >/dev/null 2>&1; then
    setsid -f "$@" >/dev/null 2>&1 </dev/null
  else
    nohup "$@" >/dev/null 2>&1 </dev/null &
  fi
}

# How to install a package on this system, for error messages.
install_hint() { # PACKAGE
  if is_macos; then
    printf 'brew install %s\n' "$1"
  else
    printf 'Install it with your package manager, e.g. sudo apt install %s (or dnf, pacman, zypper).\n' "$1"
  fi
}
