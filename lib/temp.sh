# shellcheck shell=bash
# Temporary files and folders. Each one iglass makes is removed when iglass exits, however it
# exits, so an interrupted run (Ctrl-C) never leaves half-written files behind, for example
# next to your terminal's config.
#
# A $(…) subshell that makes one removes it when the subshell ends, and never touches its
# parent's: each entry records the subshell level that made it, and the cleanup gets that level
# when the trap is set (inside the trap, bash 3.2 always reports level 0).

IGLASS_TEMPS=()

# temp_make VAR [-d] TEMPLATE — like VAR=$(mktemp [-d] TEMPLATE), and removed on exit.
temp_make() {
  local _temp_var=$1 _temp_path
  shift
  _temp_path=$(mktemp "$@") || return 1
  IGLASS_TEMPS+=("$BASH_SUBSHELL:$_temp_path")
  # shellcheck disable=SC2064  # the level is meant to be fixed now, not when the trap runs
  trap "temp_cleanup $BASH_SUBSHELL" EXIT
  printf -v "$_temp_var" '%s' "$_temp_path"
}

# temp_cleanup LEVEL — remove what this subshell level made (the EXIT trap).
temp_cleanup() {
  local entry
  for entry in ${IGLASS_TEMPS[@]+"${IGLASS_TEMPS[@]}"}; do
    if [[ "${entry%%:*}" == "$1" ]]; then
      rm -rf "${entry#*:}"
    fi
  done
  return 0
}
