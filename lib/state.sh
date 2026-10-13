# shellcheck shell=bash
# iglass's own record of what it installed and which iTerm2 settings it changed (state.json).

state_read() {
  if [[ -f "$IGLASS_STATE_FILE" ]] && jq -e 'type == "object"' "$IGLASS_STATE_FILE" >/dev/null 2>&1; then
    cat "$IGLASS_STATE_FILE"
  else
    printf '{}\n'
  fi
}

# state_get FILTER [jq args...] — query the state; prints nothing for missing values.
state_get() {
  local filter=$1
  shift
  state_read | jq -r "$@" "$filter // empty"
}

# state_update FILTER [jq args...] — apply a jq update to the state and save it atomically.
state_update() {
  local filter=$1 tmp current
  shift
  mkdir -p "$IGLASS_STATE_DIR" || die "Could not create $IGLASS_STATE_DIR."
  current=$(state_read)
  tmp=$(mktemp "$IGLASS_STATE_DIR/.state.json.XXXXXX") || die "Could not create a temporary file."
  if ! printf '%s\n' "$current" | jq "$@" "$filter" >"$tmp"; then
    rm -f "$tmp"
    die "Internal error: could not update $IGLASS_STATE_FILE."
  fi
  mv -f "$tmp" "$IGLASS_STATE_FILE"
}

state_clear_install() {
  [[ -f "$IGLASS_STATE_FILE" ]] || return 0
  state_update 'del(.options, .installedAt, .version)'
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
