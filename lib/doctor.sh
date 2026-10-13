# shellcheck shell=bash
# `iglass doctor`: read-only health checks. Exits 1 when something needs fixing.

cmd_doctor() {
  local problems=0 v app f broken=0 guids dupes font status
  ui_title "iglass doctor"

  v=$(macos_version)
  if [[ -z "$v" ]]; then
    ui_warn "Could not read the macOS version."
  elif version_ge "$v" "$IGLASS_MIN_MACOS"; then
    ui_ok "macOS $v"
  else
    ui_fail "macOS $v is older than $IGLASS_MIN_MACOS, which iglass needs."
    problems=$((problems + 1))
  fi

  app=$(iterm_app_path)
  if [[ -z "$app" ]]; then
    ui_fail "iTerm2 is not installed. Get it from https://iterm2.com"
    problems=$((problems + 1))
  else
    v=$(iterm_version)
    if [[ -n "$v" ]] && version_ge "$v" "$IGLASS_MIN_ITERM"; then
      ui_ok "iTerm2 $v ($app)"
    else
      ui_fail "iTerm2 ${v:-(unknown version)} is older than $IGLASS_MIN_ITERM, which iglass needs."
      problems=$((problems + 1))
    fi
  fi

  if [[ -d "$IGLASS_DYNPROFILES_DIR" ]]; then
    if [[ -w "$IGLASS_DYNPROFILES_DIR" ]]; then
      ui_ok "Dynamic profiles folder is writable"
    else
      ui_fail "Dynamic profiles folder is not writable: $IGLASS_DYNPROFILES_DIR"
      problems=$((problems + 1))
    fi
    # One unreadable file stops iTerm2 from loading every dynamic profile, iglass's included.
    for f in "$IGLASS_DYNPROFILES_DIR"/*; do
      [[ -f "$f" ]] || continue
      if ! plist_readable "$f"; then
        ui_fail "Unreadable profile file: $f"
        ui_dim "  iTerm2 ignores ALL dynamic profiles while this file is broken. Fix or remove it."
        broken=$((broken + 1))
      fi
    done
    if [[ $broken == 0 ]]; then
      ui_ok "All files in the dynamic profiles folder are readable"
    fi
    problems=$((problems + broken))
  else
    ui_info "Dynamic profiles folder does not exist yet (iglass install creates it)"
  fi

  if profile_installed; then
    if profile_valid "$IGLASS_PROFILE_FILE"; then
      ui_ok "iglass profiles installed"
    else
      ui_fail "iglass profile file is damaged. Run: iglass install"
      problems=$((problems + 1))
    fi
    guids=$(palette_query '[.variants[].guid, .custom.guid] | join("|")')
    dupes=""
    for f in "$IGLASS_DYNPROFILES_DIR"/*; do
      [[ -f "$f" && "$f" != "$IGLASS_PROFILE_FILE" ]] || continue
      if grep -qE "$guids" "$f" 2>/dev/null; then
        dupes="$dupes $f"
      fi
    done
    if [[ -n "$dupes" ]]; then
      ui_fail "Another file reuses iglass profile IDs:$dupes"
      ui_dim "  Two profiles with the same ID conflict. Remove the copy (e.g. an imported themes/iglass.json)."
      problems=$((problems + 1))
    fi
  else
    ui_info "iglass profiles are not installed. Run: iglass install"
  fi

  font=$(state_get '.options.font')
  if [[ -n "$font" ]]; then
    if font_available "${font% *}"; then
      ui_ok "Font ${font% *} is installed"
    else
      ui_fail "Font ${font% *} is not installed; iTerm2 will fall back to another font."
      problems=$((problems + 1))
    fi
  fi

  if prefs_custom_folder; then
    ui_warn "iTerm2 loads settings from a custom folder; iglass can't change app-wide settings."
  fi

  accessibility_hints "$(state_get '.options.variant')" "$(state_get '.options.contrast')"

  status=$(appsettings_status)
  case "$status" in
    applied) ui_ok "App-wide settings applied" ;;
    aborted) ui_warn "Last app-wide settings change was cancelled (iTerm2 didn't quit). Run iglass install --app-settings to retry." ;;
    failed)
      ui_fail "Last app-wide settings change failed: $(state_get '.appSettings.lastError')"
      problems=$((problems + 1))
      ;;
  esac
  if [[ -n "$(state_get '.appSettings.pending.id')" ]]; then
    ui_info "A settings change is waiting for iTerm2 to restart."
  fi

  echo
  if [[ $problems == 0 ]]; then
    ui_ok "No problems found."
    return 0
  fi
  ui_fail "$problems problem(s) found."
  return 1
}
