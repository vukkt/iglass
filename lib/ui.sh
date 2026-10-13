# shellcheck shell=bash
# Terminal output helpers. Colors only when stdout is a terminal and NO_COLOR is unset.

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  UI_BOLD=$'\033[1m' UI_DIM=$'\033[2m' UI_RESET=$'\033[0m'
  UI_GREEN=$'\033[32m' UI_YELLOW=$'\033[33m' UI_RED=$'\033[31m' UI_BLUE=$'\033[34m'
else
  UI_BOLD='' UI_DIM='' UI_RESET='' UI_GREEN='' UI_YELLOW='' UI_RED='' UI_BLUE=''
fi

ui_ok()    { printf '%s✓%s %s\n' "$UI_GREEN" "$UI_RESET" "$*"; }
ui_info()  { printf '%s•%s %s\n' "$UI_BLUE" "$UI_RESET" "$*"; }
ui_warn()  { printf '%s!%s %s\n' "$UI_YELLOW" "$UI_RESET" "$*" >&2; }
ui_fail()  { printf '%s✗%s %s\n' "$UI_RED" "$UI_RESET" "$*" >&2; }
ui_title() { printf '%s%s%s\n' "$UI_BOLD" "$*" "$UI_RESET"; }
ui_dim()   { printf '%s%s%s\n' "$UI_DIM" "$*" "$UI_RESET"; }

# die MESSAGE [HINT] — print an error (and an optional hint) and exit 1.
die() {
  ui_fail "$1"
  if [[ $# -gt 1 && -n "$2" ]]; then
    printf '  %s%s%s\n' "$UI_DIM" "$2" "$UI_RESET" >&2
  fi
  exit 1
}

# confirm QUESTION — ask yes/no. Returns 0 for yes.
# --yes (IGLASS_ASSUME_YES=1) answers yes; with no terminal to ask, the answer is no.
confirm() {
  if [[ "${IGLASS_ASSUME_YES:-0}" == 1 ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    return 1
  fi
  local reply
  printf '%s? %s%s [y/N] ' "$UI_BOLD" "$1" "$UI_RESET"
  read -r reply || return 1
  [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}
