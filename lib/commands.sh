# shellcheck shell=bash
# iglass subcommands.

usage() {
  cat <<EOF
${UI_BOLD}iglass${UI_RESET} $IGLASS_VERSION — a Liquid Glass–inspired theme for iTerm2

${UI_BOLD}Usage${UI_RESET}
  iglass install [options]      Install or update the iglass profiles
  iglass preview [--variant V]  Open a window with an iglass profile
  iglass list                   Show variants and accent colors
  iglass status                 Show what is installed
  iglass doctor                 Check for problems (changes nothing)
  iglass export [options]       Print the profiles file instead of installing it
  iglass uninstall              Remove iglass and undo its changes

${UI_BOLD}Look options${UI_RESET} (install, export)
  --variant clear|frosted|tinted|solid   Variant used for --default, preview and custom
                                         settings (default: frosted)
  --accent NAME        blue, purple, pink, red, orange, yellow, green, graphite
  --contrast LEVEL     standard (default) or high (stronger colors for readability)
  --cursor STYLE      bar (default), box, underline, or keep (use your own)
  --window STYLE       native (default), no-titlebar, or keep (use your own)
  --font FONT          keep (default), sf-mono, or "PostScriptName [size]"
  --opacity 0.05–1     Adds an "iglass Custom" profile with this opacity
  --blur 0–64          Adds an "iglass Custom" profile with this blur radius (0 = off)
  --force              Allow an opacity below the readable minimum

${UI_BOLD}App-wide options${UI_RESET} (install; iTerm2 restarts, original values are saved)
  --app-settings       Native title bar (Automatic theme) and roomier padding
  --default            Make the chosen variant your default profile

${UI_BOLD}Other${UI_RESET}
  -y, --yes            Answer yes to questions (also needed when not run in a terminal)
  -h, --help           Show this help
  -v, --version        Show the version

${UI_BOLD}Examples${UI_RESET}
  iglass install
  iglass install --accent purple --app-settings --default
  iglass install --variant clear --opacity 0.7 --blur 20 --force
  iglass uninstall
EOF
}

# --- look options --------------------------------------------------------------------------

OPT_VARIANT="" OPT_ACCENT="" OPT_CONTRAST="" OPT_CURSOR="bar" OPT_WINDOW="native" OPT_FONT="keep"
OPT_OPACITY="" OPT_BLUR="" OPT_FORCE=0 OPT_APP=0 OPT_DEFAULT=0

_need_value() {
  [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "$1 needs a value." "See: iglass --help"
}

_one_of() { # VALUE LIST… — true when VALUE is in LIST
  local v=$1 x
  shift
  for x in "$@"; do [[ "$x" == "$v" ]] && return 0; done
  return 1
}

# parse_look_options ALLOW_APP(0|1) ARGS… — fills the OPT_* variables.
parse_look_options() {
  local allow_app=$1
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant) _need_value "$@"; OPT_VARIANT=$2; shift 2 ;;
      --accent) _need_value "$@"; OPT_ACCENT=$2; shift 2 ;;
      --contrast) _need_value "$@"; OPT_CONTRAST=$2; shift 2 ;;
      --cursor) _need_value "$@"; OPT_CURSOR=$2; shift 2 ;;
      --window) _need_value "$@"; OPT_WINDOW=$2; shift 2 ;;
      --font) _need_value "$@"; OPT_FONT=$2; shift 2 ;;
      --opacity) _need_value "$@"; OPT_OPACITY=$2; shift 2 ;;
      --blur) _need_value "$@"; OPT_BLUR=$2; shift 2 ;;
      --force) OPT_FORCE=1; shift ;;
      --app-settings | --default)
        [[ $allow_app == 1 ]] || die "$1 only works with iglass install."
        if [[ "$1" == --default ]]; then OPT_DEFAULT=1; else OPT_APP=1; fi
        shift
        ;;
      *) die "Unknown option: $1" "See: iglass --help" ;;
    esac
  done
  _validate_look_options
}

_validate_look_options() {
  local variants accents
  # Word splitting is intended: the palette lists are space-separated names.
  # shellcheck disable=SC2207
  variants=($(palette_query '.variantOrder | join(" ")'))
  # shellcheck disable=SC2207
  accents=($(palette_query '.accentOrder | join(" ")'))

  OPT_VARIANT=${OPT_VARIANT:-$(palette_query '.defaultVariant')}
  OPT_ACCENT=${OPT_ACCENT:-$(palette_query '.defaultAccent')}
  _one_of "$OPT_VARIANT" "${variants[@]}" ||
    die "Unknown variant: $OPT_VARIANT" "Choose one of: ${variants[*]}"
  _one_of "$OPT_ACCENT" "${accents[@]}" ||
    die "Unknown accent: $OPT_ACCENT" "Choose one of: ${accents[*]}"
  _one_of "${OPT_CONTRAST:-standard}" standard high ||
    die "Unknown contrast level: $OPT_CONTRAST" "Choose one of: standard high"
  _one_of "$OPT_CURSOR" bar box underline keep ||
    die "Unknown cursor style: $OPT_CURSOR" "Choose one of: bar box underline keep"
  _one_of "$OPT_WINDOW" native no-titlebar keep ||
    die "Unknown window style: $OPT_WINDOW" "Choose one of: native no-titlebar keep"

  if [[ -n "$OPT_OPACITY" ]]; then
    [[ "$OPT_OPACITY" =~ ^(0(\.[0-9]+)?|1(\.0+)?|\.[0-9]+)$ ]] ||
      die "--opacity must be a number from 0.05 to 1 (got $OPT_OPACITY)."
    awk -v o="$OPT_OPACITY" 'BEGIN { exit !(o >= 0.05) }' ||
      die "--opacity must be at least 0.05; lower is practically invisible."
    local min_safe
    min_safe=$(palette_query '.limits.minSafeOpacity')
    if awk -v o="$OPT_OPACITY" -v m="$min_safe" 'BEGIN { exit !(o < m) }'; then
      if [[ $OPT_FORCE == 1 ]]; then
        ui_warn "Opacity $OPT_OPACITY is below $min_safe; text may be hard to read on some wallpapers."
      else
        die "Opacity $OPT_OPACITY is below $min_safe, the lowest that stays readable on typical wallpapers." \
          "Add --force to use it anyway, or pick a higher value."
      fi
    fi
  fi

  if [[ -n "$OPT_BLUR" ]]; then
    if ! [[ "$OPT_BLUR" =~ ^[0-9]+$ ]] || ((10#$OPT_BLUR > 64)); then
      die "--blur must be a whole number from 0 to 64 (got $OPT_BLUR)."
    fi
    OPT_BLUR=$((10#$OPT_BLUR))
    if ((OPT_BLUR > $(palette_query '.limits.blurRadiusWarn'))); then
      ui_warn "Blur above $(palette_query '.limits.blurRadiusWarn') can make iTerm2 slow on some Macs."
    fi
  fi

  OPT_FONT_SPEC=""
  if [[ "$OPT_FONT" != keep ]]; then
    local name size=13
    case "$OPT_FONT" in
      sf-mono | SF-Mono | "SF Mono") name="SFMono-Regular" ;;
      *)
        name=$OPT_FONT
        if [[ "$OPT_FONT" =~ ^(.+)[[:space:]]+([0-9]+(\.[0-9]+)?)$ ]]; then
          name=${BASH_REMATCH[1]}
          size=${BASH_REMATCH[2]}
        fi
        ;;
    esac
    awk -v s="$size" 'BEGIN { exit !(s >= 6 && s <= 72) }' || die "Font size must be from 6 to 72."
    if [[ "$name" == *" "* ]]; then
      die "Use the font's PostScript name, without spaces (e.g. SFMono-Regular, Menlo-Regular)." \
        "Font Book › select the font › Info shows its PostScript name."
    fi
    if ! font_available "$name"; then
      if [[ "$name" == SFMono-Regular ]]; then
        die "SF Mono is not installed." \
          "Install it from https://developer.apple.com/fonts (or open Terminal.app's copy in Font Book)."
      fi
      die "Font $name is not installed." "Check the PostScript name in Font Book › Info."
    fi
    OPT_FONT_SPEC="$name $size"
  fi
}

# The options document consumed by lib/profile.jq.
look_options_json() {
  local custom=null
  if [[ -n "$OPT_OPACITY" || -n "$OPT_BLUR" ]]; then
    custom=$(jq -n --arg base "$OPT_VARIANT" --arg opacity "$OPT_OPACITY" --arg blur "$OPT_BLUR" '
      {base: $base, overrides: (
        (if $opacity == "" then {} else
          {transparency: ((1 - ($opacity | tonumber)) * 100 | round / 100)} end)
        + (if $blur == "" then {} else
          {blur: (($blur | tonumber) > 0), blurRadius: ($blur | tonumber)} end)
      )}')
  fi
  jq -n --arg accent "$OPT_ACCENT" --arg contrast "${OPT_CONTRAST:-standard}" \
    --arg cursor "$OPT_CURSOR" --arg window "$OPT_WINDOW" \
    --arg font "$OPT_FONT_SPEC" --argjson custom "$custom" '
    {accent: $accent, contrast: $contrast, cursor: $cursor, window: $window,
     font: (if $font == "" then null else $font end), custom: $custom}'
}

# --- commands ------------------------------------------------------------------------------

cmd_install() {
  local opts selected app_v default_guid=""
  parse_look_options 1 "$@"
  opts=$(look_options_json)

  app_v=$(iterm_version)
  if [[ -z "$app_v" ]]; then
    ui_warn "iTerm2 doesn't seem to be installed. Installing the profiles anyway."
  elif ! version_ge "$app_v" "$IGLASS_MIN_ITERM"; then
    ui_warn "iTerm2 $app_v is older than $IGLASS_MIN_ITERM; light/dark colors won't switch automatically."
  fi

  profile_write "$opts"
  state_update '.version = $v | .installedAt = $t | .options = ($o + {variant: $variant})' \
    --arg v "$IGLASS_VERSION" --arg t "$(now_iso)" --argjson o "$opts" --arg variant "$OPT_VARIANT"

  selected=$OPT_VARIANT
  [[ "$(jq -r '.custom != null' <<<"$opts")" == true ]] && selected=custom
  ui_ok "Installed iglass profiles ($(palette_query '[.variants[].name] | join(", ")')$(
    [[ $selected == custom ]] && printf ', %s' "$(variant_profile_name custom)"))."
  accessibility_hints "$OPT_VARIANT" "${OPT_CONTRAST:-standard}"

  if [[ $OPT_DEFAULT == 1 ]]; then
    default_guid=$(variant_guid "$selected")
  fi
  if [[ $OPT_APP == 1 || -n "$default_guid" ]]; then
    appsettings_apply "$OPT_APP" "$default_guid"
  else
    ui_dim "  Try it: iglass preview$( [[ $selected != frosted ]] && printf ' --variant %s' "$selected")"
    ui_dim "  For the full native look add --app-settings (native title bar, roomier padding)."
  fi
}

cmd_export() {
  parse_look_options 0 "$@"
  profile_build "$(look_options_json)"
}

cmd_preview() {
  local variant="" name
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant) _need_value "$@"; variant=$2; shift 2 ;;
      *) die "Unknown option: $1" "Usage: iglass preview [--variant clear|frosted|tinted|solid|custom]" ;;
    esac
  done
  profile_installed || die "iglass is not installed." "Run: iglass install"
  if [[ -z "$variant" ]]; then
    variant=$(jq -r 'if .options.custom != null then "custom" else (.options.variant // "frosted") end' \
      <<<"$(state_read)")
  fi
  if [[ "$variant" == custom ]]; then
    jq -e --arg g "$(variant_guid custom)" '[.Profiles[].Guid] | index($g)' "$IGLASS_PROFILE_FILE" >/dev/null ||
      die "No custom profile is installed." "Create one with: iglass install --opacity 0.8"
  fi
  name=$(variant_profile_name "$variant")
  [[ -n "$name" ]] || die "Unknown variant: $variant" "Choose one of: $(palette_query '.variantOrder | join(" ")') custom"
  iterm_open_profile "$name" ||
    die "iTerm2 could not open the \"$name\" profile." "Run: iglass doctor"
  ui_ok "Opened a window with $name."
}

cmd_list() {
  local installed_variant="" installed_accent="" k
  if profile_installed; then
    installed_variant=$(state_get '.options.variant')
    installed_accent=$(state_get '.options.accent')
  fi
  ui_title "Variants"
  for k in $(palette_query '.variantOrder | join(" ")'); do
    printf '  %-9s %s%s\n' "$k" "$(palette_query '.variants[$k].description' --arg k "$k")" \
      "$([[ $k == "$installed_variant" ]] && printf ' %s(selected)%s' "$UI_DIM" "$UI_RESET")"
  done
  echo
  ui_title "Accents"
  for k in $(palette_query '.accentOrder | join(" ")'); do
    printf '  %s%s\n' "$k" "$([[ $k == "$installed_accent" ]] && printf ' %s(installed)%s' "$UI_DIM" "$UI_RESET")"
  done
}

cmd_status() {
  local status
  ui_title "iglass $IGLASS_VERSION"
  if profile_installed; then
    ui_ok "Installed $(state_get '.installedAt')"
    state_read | jq -r '.options // {} |
      "  variant \(.variant // "?") · accent \(.accent // "?") · contrast \(.contrast // "standard")",
      "  cursor \(.cursor // "?") · window \(.window // "?")",
      "  font \(.font // "your own")",
      (if .custom then "  custom profile: \(.custom.overrides | to_entries | map("\(.key)=\(.value)") | join(", "))" else empty end)'
  else
    ui_info "Not installed."
  fi
  status=$(appsettings_status)
  case "$status" in
    applied) ui_ok "App-wide settings applied (originals saved for uninstall)" ;;
    aborted) ui_warn "App-wide settings were not applied: iTerm2 did not quit." ;;
    failed) ui_fail "App-wide settings failed: $(state_get '.appSettings.lastError')" ;;
    *) ui_dim "  App-wide settings unchanged" ;;
  esac
  [[ -n "$(state_get '.appSettings.pending.id')" ]] && ui_info "A settings change is waiting for iTerm2 to restart."
  ui_dim "  iTerm2 $(iterm_version) · macOS $(macos_version)"
}

cmd_uninstall() {
  local restore=ask
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --restore-app-settings) restore=yes; shift ;;
      --keep-app-settings) restore=no; shift ;;
      *) die "Unknown option: $1" "Usage: iglass uninstall [--restore-app-settings | --keep-app-settings]" ;;
    esac
  done

  if [[ -f "$IGLASS_PROFILE_FILE" ]]; then
    if profile_is_ours "$IGLASS_PROFILE_FILE"; then
      rm -f "$IGLASS_PROFILE_FILE"
      ui_ok "Removed the iglass profiles."
    else
      ui_warn "$IGLASS_PROFILE_FILE isn't an iglass file; leaving it alone."
    fi
  else
    ui_info "iglass profiles were not installed."
  fi
  state_clear_install

  appsettings_reconcile
  if [[ -n "$(state_get '.appSettings.previous | select(length > 0) | "x"')" ]]; then
    if [[ $restore == ask ]]; then
      if confirm "Restore iTerm2's app-wide settings to how they were before iglass?"; then
        restore=yes
      else
        restore=no
      fi
    fi
    if [[ $restore == yes ]]; then
      appsettings_restore
    else
      ui_info "Kept iTerm2's app-wide settings. Restore later with: iglass uninstall --restore-app-settings"
      if [[ -n "$(state_get '.appSettings.previous["Default Bookmark Guid"] | "x"')" ]]; then
        ui_warn "Your default profile was an iglass profile; pick a new default in iTerm2 › Settings › Profiles."
      fi
    fi
  fi
}
