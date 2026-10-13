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

  if [[ -n "$(ghostty_app_path)" || -n "$(state_get '.ghostty.installedAt')" ]]; then
    _doctor_ghostty || problems=$((problems + $?))
  fi

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

# Ghostty checks. Returns the number of problems found.
_doctor_ghostty() {
  local n=0 v bin target last="" f out
  echo
  ui_title "Ghostty"
  v=$(ghostty_version)
  if [[ -z "$v" ]]; then
    ui_fail "Ghostty is not installed, but iglass files for it are. Run: iglass uninstall --terminal ghostty"
    return 1
  fi
  if version_ge "$v" "$IGLASS_MIN_GHOSTTY"; then
    ui_ok "Ghostty $v"
  else
    ui_fail "Ghostty $v is older than $IGLASS_MIN_GHOSTTY, which iglass needs."
    n=$((n + 1))
  fi
  if version_ge "$(macos_version)" 26 && ghostty_supports_native_glass; then
    ui_ok "Real Liquid Glass is available (macos-glass)"
  else
    ui_info "Real Liquid Glass needs macOS 26+ and a recent Ghostty; iglass uses blur instead"
  fi
  [[ -n "$(state_get '.ghostty.installedAt')" ]] || {
    ui_info "iglass is not installed for Ghostty. Run: iglass install --terminal ghostty"
    return $n
  }
  for f in "$(ghostty_iglass_file)" "$(ghostty_themes_dir)/iglass-frosted-dark"; do
    if [[ ! -f "$f" ]]; then
      ui_fail "Missing $f. Run: iglass install --terminal ghostty"
      n=$((n + 1))
    fi
  done
  target=$(state_get '.ghostty.config')
  if [[ -z "$target" ]] || ! ghostty_has_include "$target"; then
    ui_fail "Your Ghostty config doesn't include iglass. Run: iglass install --terminal ghostty"
    n=$((n + 1))
  else
    while IFS= read -r f; do [[ -e "$f" ]] && last=$f; done < <(ghostty_config_candidates)
    if [[ "$last" != "$target" ]]; then
      ui_warn "$last loads after $target, so its settings can override iglass."
    else
      ui_ok "Included from $target"
    fi
  fi
  # Ghostty's own check of the full config, the user's settings included.
  bin=$(ghostty_bin)
  if [[ -n "$bin" ]] && ! out=$("$bin" +validate-config 2>&1); then
    ui_fail "Ghostty reports problems in your configuration:"
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    n=$((n + 1))
  else
    ui_ok "Ghostty accepts your configuration"
  fi
  return $n
}
