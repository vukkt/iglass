# shellcheck shell=bash
# Opt-in changes to iTerm2's app-wide preferences, with exact restore.
#
# state.json keeps, under .appSettings:
#   previous  {key: {present, type, value}}  each key's value before iglass first touched it
#   status    "applied" | "aborted" | "failed"
#   pending   {op: "apply"|"restore", id}      set while the helper has not reported back
# The helper reports through $IGLASS_STATE_DIR/apply-result; appsettings_reconcile reads it.

APPSETTINGS_RESULT_FILE_NAME="apply-result"

# appsettings_targets LOOK(0|1) DEFAULT_GUID — print "key<TAB>type<TAB>value" lines.
appsettings_targets() {
  if [[ "$1" == 1 ]]; then
    printf 'TabStyleWithAutomaticOption\tinteger\t4\n' # Automatic theme: system-drawn title bar
    printf 'TerminalMargin\tinteger\t12\n'             # side padding
    printf 'TerminalVMargin\tinteger\t10\n'            # top/bottom padding
  fi
  if [[ -n "$2" ]]; then
    printf 'Default Bookmark Guid\tstring\t%s\n' "$2"
  fi
}

prefs_custom_folder() {
  [[ "$(defaults read "$IGLASS_PREFS_DOMAIN" LoadPrefsFromCustomFolder 2>/dev/null)" == 1 ]]
}

# prefs_type KEY — integer, float, boolean, string, …; nothing when the key is absent.
prefs_type() {
  local out
  out=$(defaults read-type "$IGLASS_PREFS_DOMAIN" "$1" 2>/dev/null) || return 0
  printf '%s\n' "${out#Type is }"
}

prefs_value() {
  defaults read "$IGLASS_PREFS_DOMAIN" "$1" 2>/dev/null
}

# Fold a finished helper run into state.json. Safe to call any time.
appsettings_reconcile() {
  local result="$IGLASS_STATE_DIR/$APPSETTINGS_RESULT_FILE_NAME"
  local pending_id pending_op id status message
  pending_id=$(state_get '.appSettings.pending.id')
  [[ -n "$pending_id" && -f "$result" ]] || return 0
  IFS=$'\t' read -r id status message <"$result" || return 0
  [[ "$id" == "$pending_id" ]] || return 0
  pending_op=$(state_get '.appSettings.pending.op')
  case "$pending_op:$status" in
    restore:applied)
      state_update 'del(.appSettings)'
      ;;
    restore:*)
      state_update '.appSettings |= (del(.pending) | .status = "applied" | .lastError = $m)' \
        --arg m "$message"
      ;;
    apply:*)
      state_update '.appSettings |= (del(.pending) | .status = $s | .lastError = $m | .updatedAt = $t)' \
        --arg s "$status" --arg m "$message" --arg t "$(now_iso)"
      ;;
  esac
  rm -f "$result"
}

appsettings_status() {
  appsettings_reconcile
  state_get '.appSettings.status'
}

# Ask before restarting iTerm2. Returns 1 when the user declines.
_appsettings_confirm_restart() {
  iterm_running || return 0
  ui_info "iTerm2 has to quit to change app-wide settings. iglass will quit it, apply the"
  ui_info "change, and open it again. iTerm2 may ask you to confirm closing running programs."
  confirm "Restart iTerm2 now?"
}

# _appsettings_run PLAN OP — run the helper now (iTerm2 closed) or via launchd (iTerm2 open).
_appsettings_run() {
  local plan=$1 op=$2 id label helper result
  id="$(date +%Y%m%d%H%M%S)-$$"
  helper="$IGLASS_ROOT/lib/apply-helper.sh"
  result="$IGLASS_STATE_DIR/$APPSETTINGS_RESULT_FILE_NAME"
  rm -f "$result"
  state_update '.appSettings.pending = {op: $op, id: $id}' --arg op "$op" --arg id "$id"

  if iterm_running; then
    label="com.github.vukkt.iglass.apply.$id"
    if ! launchctl submit -l "$label" -- /bin/bash "$helper" \
      "$IGLASS_PREFS_DOMAIN" "$plan" "$result" "$id" "$IGLASS_APPLY_TIMEOUT" \
      "$IGLASS_ITERM_PROCESS" "$label"; then
      state_update '.appSettings |= del(.pending)'
      die "Could not start the background helper (launchctl submit failed)."
    fi
    ui_ok "iTerm2 will quit and reopen in a moment to apply the change."
    ui_dim "  Check the result afterwards with: iglass status"
    return 0
  fi

  /bin/bash "$helper" "$IGLASS_PREFS_DOMAIN" "$plan" "$result" "$id" \
    "$IGLASS_APPLY_TIMEOUT" "$IGLASS_ITERM_PROCESS"
  appsettings_reconcile
  case "$op:$(state_get '.appSettings.status')" in
    restore:) ui_ok "Restored iTerm2's app-wide settings." ;;
    apply:applied) ui_ok "Applied iTerm2 app-wide settings." ;;
    *) die "Could not change iTerm2's settings: $(state_get '.appSettings.lastError')" ;;
  esac
}

# appsettings_apply LOOK(0|1) DEFAULT_GUID
appsettings_apply() {
  local look=$1 default_guid=$2 targets key type value prev_type plan backup_dir backup
  targets=$(appsettings_targets "$look" "$default_guid")
  [[ -n "$targets" ]] || return 0
  appsettings_reconcile
  if [[ -n "$(state_get '.appSettings.pending.id')" ]]; then
    die "A previous settings change has not finished yet." \
      "Wait for iTerm2 to restart, then run: iglass status"
  fi
  if prefs_custom_folder; then
    die "iTerm2 loads its settings from a custom folder, so iglass can't change them safely." \
      "Set the theme in iTerm2 › Settings › Appearance › General instead."
  fi
  _appsettings_confirm_restart || die "Nothing changed." "Run again from Terminal.app, or quit iTerm2 first."

  # Remember each key's original value the first time iglass touches it, so uninstall can put
  # back exactly what was there (and delete keys that did not exist).
  while IFS=$'\t' read -r key type value; do
    [[ -n "$(state_get '.appSettings.previous[$k] | select(. != null) | "x"' --arg k "$key")" ]] && continue
    prev_type=$(prefs_type "$key")
    case "$prev_type" in
      "")
        state_update '.appSettings.previous[$k] = {present: false}' --arg k "$key"
        ;;
      integer | float | boolean | string)
        state_update '.appSettings.previous[$k] = {present: true, type: $t, value: $v}' \
          --arg k "$key" --arg t "$prev_type" --arg v "$(prefs_value "$key")"
        ;;
      *)
        die "iTerm2's \"$key\" setting has an unexpected type ($prev_type); not changing it."
        ;;
    esac
  done <<<"$targets"

  # Full backup. The first one, taken before iglass changed anything, is never overwritten.
  backup_dir="$IGLASS_STATE_DIR/backups"
  backup="$backup_dir/iterm2-prefs-before-iglass.plist"
  [[ -f "$backup" ]] && backup="$backup_dir/iterm2-prefs-$(date +%Y%m%d-%H%M%S)-$$.plist"
  mkdir -p "$backup_dir"
  defaults export "$IGLASS_PREFS_DOMAIN" "$backup" 2>/dev/null ||
    ui_warn "Could not back up iTerm2's preferences (continuing; original values are still recorded)."

  plan="$IGLASS_STATE_DIR/apply-plan.tsv"
  while IFS=$'\t' read -r key type value; do
    printf 'write\t%s\t%s\t%s\n' "$key" "$type" "$value"
  done <<<"$targets" >"$plan"
  _appsettings_run "$plan" apply
}

# Put back every key iglass changed. Returns 0 when there was nothing to restore.
appsettings_restore() {
  local plan
  appsettings_reconcile
  [[ -n "$(state_get '.appSettings.previous | select(length > 0) | "x"')" ]] || return 0
  if [[ -n "$(state_get '.appSettings.pending.id')" ]]; then
    die "A previous settings change has not finished yet." "Wait for iTerm2 to restart, then try again."
  fi
  if prefs_custom_folder; then
    die "iTerm2 loads its settings from a custom folder, so iglass can't restore them." \
      "Restore manually from a backup in $IGLASS_STATE_DIR/backups."
  fi
  _appsettings_confirm_restart || die "Nothing changed." "Run again from Terminal.app, or quit iTerm2 first."
  plan="$IGLASS_STATE_DIR/apply-plan.tsv"
  state_read | jq -r '
    .appSettings.previous | to_entries[]
    | if .value.present then ["write", .key, .value.type, .value.value] else ["delete", .key] end
    | @tsv' >"$plan"
  _appsettings_run "$plan" restore
}
