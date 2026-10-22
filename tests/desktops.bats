#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031  # per-test exports are meant to stay inside each test
# Linux desktops and distributions: which desktops blur behind which terminal (KDE Plasma,
# Hyprland, niri 26.04+, GNOME 51+), and install hints for the distribution's package manager.

load helpers

setup() {
  setup_sandbox
  use_linux none
  unset IGLASS_STATE_DIR
  export XDG_STATE_HOME="$SANDBOX/state-home"
  K="$HOME/.config/kitty"
  G="$IGLASS_GHOSTTY_XDG_DIR"
}

os_release() { # ID ID_LIKE NAME
  printf 'NAME="%s"\nID=%s\nID_LIKE="%s"\n' "$3" "$1" "$2" >"$IGLASS_OS_RELEASE"
}

@test "niri 26.04 blurs behind kitty: Frosted by default, and doctor says so" {
  fake_kitty 0.49.2
  export XDG_CURRENT_DESKTOP=niri MOCK_NIRI=26.04
  run "$IGLASS" install --terminal kitty
  assert_success_
  [[ "$output" != *"blur behind windows"* ]] || false
  assert_output_has "Installed iglass for kitty (blur, "
  grep -qx 'background_opacity 0.66' "$K/iglass.conf"
  run "$IGLASS" doctor
  assert_output_has "Fedora Linux 43 · niri 26.04"
  assert_output_has "niri 26.04 blurs behind kitty"
}

@test "niri before 26.04 has no blur: Tinted, and the version that adds it" {
  export XDG_CURRENT_DESKTOP=niri MOCK_NIRI=25.11
  run "$IGLASS" install --terminal kitty # not installed yet: just that, no talk of blur
  assert_failure_
  [[ "$output" != *"blur"* ]] || false
  fake_kitty 0.49.2
  run "$IGLASS" install --terminal kitty
  assert_success_
  assert_output_has "niri 25.11 doesn't blur behind windows (niri 26.04+ does), so iglass uses Tinted"
  assert_output_has "for kitty (transparency, no blur on this desktop"
  grep -qx 'background_opacity 0.82' "$K/iglass.conf"
}

@test "niri 26.04 with a kitty that doesn't ask for blur: Tinted, and a window rule for niri" {
  fake_kitty 0.45.0
  export XDG_CURRENT_DESKTOP=niri MOCK_NIRI=26.04
  run "$IGLASS" install --terminal kitty
  assert_success_
  assert_output_has "niri blurs behind apps that ask for it, which kitty does from 0.46.2 (this is kitty 0.45.0)"
  assert_output_has 'match app-id="^kitty$"'
  assert_output_has "background-effect {"
}

@test "niri 26.04 and Ghostty: blur from Ghostty 1.4, a niri window rule before that" {
  use_linux 1.3.1
  export XDG_CURRENT_DESKTOP=niri MOCK_NIRI=26.04
  run "$IGLASS" install --terminal ghostty
  assert_success_
  assert_output_has "niri blurs behind apps that ask for it, which Ghostty does from 1.4 (this is Ghostty 1.3.1)"
  assert_output_has 'match app-id="^com\.mitchellh\.ghostty$"'
  assert_output_has "Then pick a glassier look: iglass install --variant frosted"
  assert_output_has "for Ghostty (transparency, no blur on this desktop"
  run "$IGLASS" doctor
  assert_output_has "which Ghostty does from 1.4"
  assert_output_has "Until then, niri can blur it with a window rule"

  use_linux 1.4.0
  run "$IGLASS" install --terminal ghostty
  [[ "$output" != *"blur behind windows"* && "$output" != *"window-rule"* ]] || false
  assert_output_has "Updated iglass for Ghostty (blur, "
  grep -qx 'theme = light:iglass-frosted-light,dark:iglass-frosted-dark' "$G/iglass.ghostty"
}

@test "GNOME 51 blurs behind kitty; GNOME 50 and Ghostty before 1.4 don't" {
  fake_kitty 0.49.2
  export XDG_CURRENT_DESKTOP=ubuntu:GNOME MOCK_GNOME=51.1
  run "$IGLASS" install --terminal kitty
  assert_output_has "Installed iglass for kitty (blur, "
  run "$IGLASS" doctor
  assert_output_has "GNOME 51.1 blurs behind kitty"

  MOCK_GNOME=50.6 run "$IGLASS" install --terminal kitty
  assert_output_has "GNOME 50.6 doesn't blur behind windows (GNOME 51+ does), so iglass uses Tinted"

  use_linux 1.3.1
  run "$IGLASS" install --terminal ghostty
  assert_output_has "GNOME blurs behind apps that ask for it, which Ghostty does from 1.4"
  [[ "$output" != *"window-rule"* ]] || false # window rules are a niri feature
}

@test "--terminal all picks Tinted when the desktop blurs behind only one of them" {
  use_linux 1.3.1
  fake_kitty 0.49.2
  export XDG_CURRENT_DESKTOP=niri MOCK_NIRI=26.04
  run "$IGLASS" install --terminal all
  assert_success_
  assert_output_has "which Ghostty does from 1.4"
  grep -qx 'theme = light:iglass-tinted-light,dark:iglass-tinted-dark' "$G/iglass.ghostty"
  grep -qx 'background_opacity 0.82' "$K/iglass.conf"
}

@test "other desktops: the message names the ones that blur" {
  fake_kitty 0.49.2
  XDG_CURRENT_DESKTOP=sway run "$IGLASS" install --terminal kitty
  assert_output_has "sway doesn't blur behind windows (KDE Plasma, Hyprland, niri 26.04+ and GNOME 51+ do)"
  XDG_CURRENT_DESKTOP=Hyprland run "$IGLASS" install --terminal kitty
  assert_output_has "Updated iglass for kitty (blur, "
}

@test "Garuda and other Arch-based systems are told to use pacman" {
  os_release garuda arch "Garuda Linux"
  export XDG_CURRENT_DESKTOP=KDE
  run "$IGLASS" install --terminal kitty
  assert_failure_
  assert_output_has "Get kitty with: sudo pacman -S kitty, or from https://sw.kovidgoyal.net/kitty/binary/"
  run "$IGLASS" install
  assert_output_has "sudo pacman -S ghostty"
  run "$IGLASS" doctor
  assert_output_has "Garuda Linux · KDE Plasma"
  assert_output_has "sudo pacman -S kitty"
  for like in "cachyos arch" "manjaro arch" "endeavouros arch"; do
    os_release "${like% *}" "${like#* }" "$like"
    run "$IGLASS" install --terminal kitty
    assert_output_has "sudo pacman -S kitty"
  done
}

@test "Debian, Ubuntu, Fedora and openSUSE get their own package manager" {
  export XDG_CURRENT_DESKTOP=KDE
  os_release ubuntu debian Ubuntu
  run "$IGLASS" install --terminal kitty
  assert_output_has "sudo apt install kitty"
  run "$IGLASS" install --terminal ghostty
  assert_output_has "Get Ghostty from https://ghostty.org/download" # not in Ubuntu's repositories
  os_release fedora "" "Fedora Linux"
  run "$IGLASS" install --terminal kitty
  assert_output_has "sudo dnf install kitty"
  os_release opensuse-tumbleweed "opensuse suse" "openSUSE Tumbleweed"
  run "$IGLASS" install --terminal kitty
  assert_output_has "sudo zypper install kitty"
  os_release nixos "" NixOS
  run "$IGLASS" install --terminal kitty
  assert_output_has "Get kitty from https://sw.kovidgoyal.net/kitty/binary/"
}

@test "install.sh names the distribution's package manager when jq is missing" {
  os_release garuda arch "Garuda Linux"
  # A PATH with the few tools install.sh needs before its jq check, and no jq.
  local tools="$SANDBOX/tools" t
  mkdir -p "$tools"
  for t in bash sed tr dirname cat; do ln -s "$(command -v "$t")" "$tools/$t"; done
  printf '#!/bin/sh\necho Linux\n' >"$tools/uname"
  chmod +x "$tools/uname"
  run env PATH="$tools" "$tools/bash" "$REPO_ROOT/install.sh" --local --prefix "$SANDBOX/prefix"
  assert_failure_
  assert_output_has "iglass needs jq. Install it with: sudo pacman -S jq"
}
