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

# The desktop: kde, gnome, hyprland or niri, else the first name in XDG_CURRENT_DESKTOP (which
# may list several, e.g. ubuntu:GNOME).
desktop_id() {
  case ":${XDG_CURRENT_DESKTOP:-}:" in
    *:KDE:*) printf 'kde\n' ;;
    *:Hyprland:*) printf 'hyprland\n' ;;
    *:niri:*) printf 'niri\n' ;;
    *:GNOME:*) printf 'gnome\n' ;;
    *) printf '%s\n' "${XDG_CURRENT_DESKTOP%%:*}" ;;
  esac
}

# The desktop's name for messages, e.g. KDE Plasma or GNOME; empty when unknown.
desktop_name() {
  case "$(desktop_id)" in
    kde) printf 'KDE Plasma\n' ;;
    gnome) printf 'GNOME\n' ;;
    hyprland) printf 'Hyprland\n' ;;
    niri) printf 'niri\n' ;;
    *) desktop_id ;;
  esac
}

# The desktop's version where blur depends on it (niri, GNOME), e.g. 26.04 or 51.1.
desktop_version() {
  case "$(desktop_id)" in
    niri) niri --version 2>/dev/null | sed -n '1s/^niri \([0-9][0-9.]*\).*/\1/p' ;;
    gnome) gnome-shell --version 2>/dev/null | sed -n '1s/^GNOME Shell \([0-9][0-9.]*\).*/\1/p' ;;
  esac
}

# The desktop and its version, e.g. "niri 26.04", for doctor.
desktop_description() {
  local name v
  name=$(desktop_name)
  [[ -n "$name" ]] || return 0
  v=$(desktop_version)
  printf '%s\n' "$name${v:+ $v}"
}

# Blur on Linux comes from the desktop. KDE Plasma (KWin) blurs when the terminal asks, and
# Hyprland blurs translucent windows itself. niri 26.04+ and GNOME 51+ blur when the app asks
# through the ext-background-effect protocol, which kitty does from 0.46.2 and Ghostty from 1.4.
# Elsewhere the background shows through sharply, and only Tinted and Solid stay readable.
IGLASS_MIN_NIRI_BLUR=26.04
IGLASS_MIN_GNOME_BLUR=51
IGLASS_MIN_KITTY_BLUR_REQUEST=0.46.2
IGLASS_MIN_GHOSTTY_BLUR_REQUEST=1.4

# desktop_blurs TERMINAL — true when the desktop blurs behind this terminal's windows.
desktop_blurs() {
  [[ -z "$(desktop_blur_gap "$1")" ]]
}

# desktop_blur_gap TERMINAL — why the desktop doesn't blur behind this terminal, as a sentence
# without a full stop; nothing when it does.
desktop_blur_gap() {
  local id name v min app="" app_v="" app_min=""
  id=$(desktop_id)
  name=$(desktop_name)
  case "$id" in
    kde | hyprland) return 0 ;;
    niri) min=$IGLASS_MIN_NIRI_BLUR ;;
    gnome) min=$IGLASS_MIN_GNOME_BLUR ;;
    *)
      printf "%s doesn't blur behind windows (KDE Plasma, Hyprland, niri %s+ and GNOME %s+ do)\n" \
        "${name:-This desktop}" "$IGLASS_MIN_NIRI_BLUR" "$IGLASS_MIN_GNOME_BLUR"
      return 0
      ;;
  esac
  v=$(desktop_version)
  if [[ -z "$v" ]] || ! version_ge "$v" "$min"; then
    printf "%s doesn't blur behind windows (%s %s+ does)\n" "$name${v:+ $v}" "$name" "$min"
    return 0
  fi
  case "$1" in
    kitty) app=kitty app_v=$(kitty_version) app_min=$IGLASS_MIN_KITTY_BLUR_REQUEST ;;
    ghostty) app=Ghostty app_v=$(ghostty_version) app_min=$IGLASS_MIN_GHOSTTY_BLUR_REQUEST ;;
    *) return 0 ;;
  esac
  if [[ -z "$app_v" ]]; then
    printf '%s blurs behind apps that ask for it, which %s does from %s\n' "$name" "$app" "$app_min"
  elif ! version_ge "$app_v" "$app_min"; then
    printf '%s blurs behind apps that ask for it, which %s does from %s (this is %s %s)\n' \
      "$name" "$app" "$app_min" "$app" "$app_v"
  fi
}

# desktop_blur_tip TERMINAL — how to get blur anyway where the desktop can add it itself (niri
# window rules), for a terminal that doesn't ask yet. Nothing elsewhere.
desktop_blur_tip() {
  [[ "$(desktop_id)" == niri ]] && version_ge "$(desktop_version)" "$IGLASS_MIN_NIRI_BLUR" || return 0
  local app_id
  case "$1" in
    kitty) app_id='^kitty$' ;;
    ghostty) app_id='^com\.mitchellh\.ghostty$' ;;
    *) return 0 ;;
  esac
  printf '%s\n' "  Until then, niri can blur it with a window rule in ~/.config/niri/config.kdl:" \
    "    window-rule {" \
    "        match app-id=\"$app_id\"" \
    "        background-effect {" \
    "            blur true" \
    "        }" \
    "    }" \
    "  Then pick a glassier look: iglass install --variant frosted"
}

# The Linux distribution's family: arch (Arch, Garuda, CachyOS, Manjaro, EndeavourOS…), debian
# (Debian, Ubuntu, Mint, Pop!_OS…), fedora, suse, or nothing. From ID and ID_LIKE in os-release.
distro_family() {
  is_linux || return 0
  local file=${IGLASS_OS_RELEASE:-/etc/os-release} ids
  [[ -r "$file" ]] || return 0
  ids=" $(sed -n -e 's/^ID=//p' -e 's/^ID_LIKE=//p' "$file" | tr -d '"' | tr '\n' ' ') "
  case "$ids" in
    *" arch "*) printf 'arch\n' ;;
    *" debian "* | *" ubuntu "*) printf 'debian\n' ;;
    *" fedora "* | *" rhel "*) printf 'fedora\n' ;;
    *suse*) printf 'suse\n' ;;
  esac
}

# The command that installs a package from the distribution's repositories, e.g.
# "sudo pacman -S jq"; nothing when the distribution is unknown.
package_command() { # PACKAGE
  case "$(distro_family)" in
    arch) printf 'sudo pacman -S %s\n' "$1" ;;
    debian) printf 'sudo apt install %s\n' "$1" ;;
    fedora) printf 'sudo dnf install %s\n' "$1" ;;
    suse) printf 'sudo zypper install %s\n' "$1" ;;
  esac
}

# How to install a package on this system, for error messages.
install_hint() { # PACKAGE
  local cmd
  if is_macos; then
    printf 'brew install %s\n' "$1"
    return
  fi
  cmd=$(package_command "$1")
  if [[ -n "$cmd" ]]; then
    printf 'Install it with: %s\n' "$cmd"
  else
    printf 'Install it with your package manager, e.g. sudo apt install %s (or dnf, pacman, zypper).\n' "$1"
  fi
}

# Where to get Ghostty or kitty on this system, for messages. Ghostty is packaged only in Arch's
# repositories; kitty is in all of them (its own installer has the newest version).
terminal_get_hint() { # ghostty|kitty
  local cmd=""
  case "$1" in
    ghostty)
      [[ "$(distro_family)" == arch ]] && cmd=$(package_command ghostty)
      printf '%s\n' "Get Ghostty${cmd:+ with: $cmd, or} from https://ghostty.org/download"
      ;;
    kitty)
      is_linux && cmd=$(package_command kitty)
      printf '%s\n' "Get kitty${cmd:+ with: $cmd, or} from https://sw.kovidgoyal.net/kitty/binary/"
      ;;
  esac
}
