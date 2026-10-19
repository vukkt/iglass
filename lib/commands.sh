# shellcheck shell=bash
# iglass subcommands.

usage() {
  cat <<EOF
${UI_BOLD}iglass${UI_RESET} $IGLASS_VERSION — a Liquid Glass–inspired theme for iTerm2, Ghostty and kitty
(macOS), and Ghostty and kitty (Linux)

${UI_BOLD}Usage${UI_RESET}
  iglass install [options]      Install or update iglass
  iglass preview [--variant V]  Open a window with an iglass variant
  iglass list                   Show variants and accent colors
  iglass status                 Show what is installed
  iglass doctor                 Check for problems (changes nothing)
  iglass export [options]       Print the iTerm2 profiles (or write Ghostty or kitty files with --dir)
  iglass uninstall              Remove iglass and undo its changes

${UI_BOLD}Terminal${UI_RESET} (install, preview, export, uninstall)
  --terminal NAME      iterm2, ghostty, kitty or all (default: the terminal you're running in;
                       uninstall defaults to all; all skips terminals that aren't installed)
  --glass MODE         Ghostty only: auto (default), native (real Liquid Glass, macOS 26+)
                       or blur (always blur on Linux)

${UI_BOLD}Look options${UI_RESET} (install, export)
  --variant clear|frosted|tinted|solid   Variant used for --default, preview and custom
                                         settings (default: frosted)
  --accent NAME        blue, purple, pink, red, orange, yellow, green, graphite
  --contrast LEVEL     standard (default) or high (stronger colors for readability)
  --appearance MODE    auto (default: follow light/dark mode), dark or light (always)
  --cursor STYLE      bar (default), box, underline, or keep (use your own)
  --window STYLE       native (default), no-titlebar, or keep (use your own)
  --font FONT          keep (default), sf-mono, or "PostScriptName [size]"
  --opacity 0.05–1     Adds an "iglass Custom" profile with this opacity
  --blur 0–64          Adds an "iglass Custom" profile with this blur radius (0 = off)
  --force              Allow an opacity below the readable minimum

${UI_BOLD}App-wide options${UI_RESET} (install, iTerm2 on macOS only; iTerm2 restarts, original values are saved)
  --app-settings       Native title bar (Automatic theme) and roomier padding
  --default            Make the chosen variant your default profile

${UI_BOLD}Other${UI_RESET}
  -y, --yes            Answer yes to questions (also needed when not run in a terminal)
  -h, --help           Show this help
  -v, --version        Show the version

${UI_BOLD}Examples${UI_RESET}
  iglass install
  iglass install --terminal ghostty --accent purple
  iglass install --accent purple --app-settings --default
  iglass install --variant clear --opacity 0.7 --blur 20 --force
  iglass uninstall
EOF
}

# --- look options --------------------------------------------------------------------------

OPT_VARIANT="" OPT_ACCENT="" OPT_CONTRAST="" OPT_APPEARANCE="auto" OPT_CURSOR="bar" OPT_WINDOW="native" OPT_FONT="keep"
OPT_OPACITY="" OPT_BLUR="" OPT_FORCE=0 OPT_APP=0 OPT_DEFAULT=0
OPT_TERMINAL="" OPT_GLASS="auto" OPT_DIR=""

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
      --appearance) _need_value "$@"; OPT_APPEARANCE=$2; shift 2 ;;
      --cursor) _need_value "$@"; OPT_CURSOR=$2; shift 2 ;;
      --window) _need_value "$@"; OPT_WINDOW=$2; shift 2 ;;
      --font) _need_value "$@"; OPT_FONT=$2; shift 2 ;;
      --opacity) _need_value "$@"; OPT_OPACITY=$2; shift 2 ;;
      --blur) _need_value "$@"; OPT_BLUR=$2; shift 2 ;;
      --force) OPT_FORCE=1; shift ;;
      --terminal) _need_value "$@"; OPT_TERMINAL=$2; shift 2 ;;
      --glass) _need_value "$@"; OPT_GLASS=$2; shift 2 ;;
      --dir)
        [[ $allow_app == 0 ]] || die "--dir only works with iglass export."
        _need_value "$@"; OPT_DIR=$2; shift 2
        ;;
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

  _choose_linux_variant
  OPT_VARIANT=${OPT_VARIANT:-$(palette_query '.defaultVariant')}
  OPT_ACCENT=${OPT_ACCENT:-$(palette_query '.defaultAccent')}
  _one_of "$OPT_VARIANT" "${variants[@]}" ||
    die "Unknown variant: $OPT_VARIANT" "Choose one of: ${variants[*]}"
  _one_of "$OPT_ACCENT" "${accents[@]}" ||
    die "Unknown accent: $OPT_ACCENT" "Choose one of: ${accents[*]}"
  _one_of "${OPT_CONTRAST:-standard}" standard high ||
    die "Unknown contrast level: $OPT_CONTRAST" "Choose one of: standard high"
  _one_of "$OPT_APPEARANCE" auto dark light ||
    die "Unknown appearance: $OPT_APPEARANCE" "Choose one of: auto dark light"
  _one_of "$OPT_CURSOR" bar box underline keep ||
    die "Unknown cursor style: $OPT_CURSOR" "Choose one of: bar box underline keep"
  _one_of "$OPT_WINDOW" native no-titlebar keep ||
    die "Unknown window style: $OPT_WINDOW" "Choose one of: native no-titlebar keep"
  _one_of "$OPT_GLASS" auto native blur ||
    die "Unknown glass mode: $OPT_GLASS" "Choose one of: auto native blur"
  if is_linux && [[ "$OPT_GLASS" == native && "${IGLASS_COMMAND:-}" != export ]]; then
    die "Real Liquid Glass is a macOS material; on Linux iglass uses transparency and blur." \
      "Leave out --glass, or use --glass blur."
  fi
  _validate_terminal_option

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
    local where="Font Book › select the font › Info shows its PostScript name."
    is_linux && where="List PostScript names with: fc-list : postscriptname | sort"
    if [[ "$name" == *" "* ]]; then
      die "Use the font's PostScript name, without spaces (e.g. SFMono-Regular, JetBrainsMono-Regular)." "$where"
    fi
    if ! font_available "$name"; then
      if [[ "$name" == SFMono-Regular ]] && is_macos; then
        die "SF Mono is not installed." \
          "Install it from https://developer.apple.com/fonts (or open Terminal.app's copy in Font Book)."
      fi
      die "Font $name is not installed." "$where"
    fi
    OPT_FONT_SPEC="$name $size"
    OPT_FONT_FAMILY=$(font_family "$name")
    OPT_FONT_SIZE=$size
  fi
}

# Clear and Frosted are contrast-checked assuming blur softens what's behind the window. On a
# Linux desktop that doesn't blur, install defaults to Tinted and warns about the other two.
_choose_linux_variant() {
  is_linux && [[ "${IGLASS_COMMAND:-}" == install ]] && ! desktop_blurs || return 0
  local desktop
  desktop=$(desktop_name)
  desktop=${desktop:-your desktop}
  if [[ -z "$OPT_VARIANT" ]]; then
    OPT_VARIANT=tinted
    ui_info "$desktop doesn't blur behind windows, so iglass uses Tinted, which stays readable over anything. Pick another with --variant."
  elif [[ "$OPT_VARIANT" == clear || "$OPT_VARIANT" == frosted ]]; then
    ui_warn "$desktop doesn't blur behind windows, so whatever is behind the terminal will show through $OPT_VARIANT sharply. Tinted or Solid stay readable."
  fi
}

_validate_terminal_option() {
  [[ -n "$OPT_TERMINAL" ]] || return 0
  _one_of "$OPT_TERMINAL" iterm2 ghostty kitty all ||
    die "Unknown terminal: $OPT_TERMINAL" "Choose one of: iterm2 ghostty kitty all"
  # Exporting iTerm2 profiles is just writing JSON, so it works anywhere.
  if is_linux && [[ "$OPT_TERMINAL" == iterm2 && "${IGLASS_COMMAND:-}" != export ]]; then
    die "iTerm2 is macOS-only. On Linux iglass supports Ghostty and kitty." "Use --terminal ghostty or --terminal kitty."
  fi
}

# Terminals to act on: --terminal, else the one this runs in (all for uninstall).
resolve_terminals() { # DEFAULT(detect|all)
  local t=${OPT_TERMINAL:-}
  if [[ -z "$t" ]]; then
    if [[ "$1" == all ]]; then t=all; else t=$(detect_terminal); fi
  fi
  if [[ "$t" == all ]]; then
    if is_macos; then printf 'iterm2 ghostty kitty\n'; else printf 'ghostty kitty\n'; fi
  else
    printf '%s\n' "$t"
  fi
}

# Options for the Ghostty files: the iTerm2 options plus variant, glass mode and font family.
ghostty_options_json() { # BASE_OPTIONS_JSON
  jq -n --argjson o "$1" --arg variant "$OPT_VARIANT" --arg glass "$(ghostty_glass_mode "$OPT_GLASS")" \
    --arg version "$IGLASS_VERSION" --arg family "${OPT_FONT_FAMILY:-}" --arg size "${OPT_FONT_SIZE:-}" \
    --arg platform "$IGLASS_PLATFORM" '
    $o + {variant: $variant, glass: $glass, version: $version, platform: $platform,
          fontFamily: (if $family == "" then null else $family end),
          fontSize: (if $size == "" then null else ($size | tonumber) end)}'
}

# Options for the kitty files: the shared options plus variant, version and font family.
kitty_options_json() { # BASE_OPTIONS_JSON
  jq -n --argjson o "$1" --arg variant "$OPT_VARIANT" --arg version "$IGLASS_VERSION" \
    --arg family "${OPT_FONT_FAMILY:-}" --arg size "${OPT_FONT_SIZE:-}" '
    $o + {variant: $variant, version: $version,
          fontFamily: (if $family == "" then null else $family end),
          fontSize: (if $size == "" then null else ($size | tonumber) end)}'
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
    --arg appearance "$OPT_APPEARANCE" --arg cursor "$OPT_CURSOR" --arg window "$OPT_WINDOW" \
    --arg font "$OPT_FONT_SPEC" --argjson custom "$custom" '
    {accent: $accent, contrast: $contrast, appearance: $appearance, cursor: $cursor, window: $window,
     font: (if $font == "" then null else $font end), custom: $custom}'
}

# --- commands ------------------------------------------------------------------------------

cmd_install() {
  local opts terminals t
  parse_look_options 1 "$@"
  opts=$(look_options_json)
  terminals=$(resolve_terminals detect)
  if [[ ($OPT_APP == 1 || $OPT_DEFAULT == 1) ]] && is_linux; then
    die "--app-settings and --default are iTerm2 settings, and iTerm2 is macOS-only." \
      "On Linux, set Ghostty as your default terminal in your desktop's settings."
  fi
  if [[ ($OPT_APP == 1 || $OPT_DEFAULT == 1) && " $terminals " != *" iterm2 "* ]]; then
    die "--app-settings and --default are iTerm2 settings." "Add --terminal iterm2 (or all)."
  fi
  local installed_count=0
  for t in $terminals; do
    if [[ "$OPT_TERMINAL" == all ]]; then
      case "$t" in
        ghostty) ghostty_present || { ui_dim "  Ghostty isn't installed; skipped."; continue; } ;;
        kitty) kitty_present || { ui_dim "  kitty isn't installed; skipped."; continue; } ;;
      esac
    fi
    case "$t" in
      iterm2) _install_iterm2 "$opts" ;;
      ghostty) _install_ghostty "$opts" ;;
      kitty) _install_kitty "$opts" ;;
    esac
    installed_count=$((installed_count + 1))
  done
  if [[ $installed_count == 0 ]]; then
    die "None of the terminals iglass supports is installed." "Install Ghostty (ghostty.org) or kitty (sw.kovidgoyal.net/kitty)."
  fi
}

_install_iterm2() {
  local opts=$1 selected app_v default_guid="" first=0
  app_v=$(iterm_version)
  if [[ -z "$app_v" ]]; then
    ui_warn "iTerm2 doesn't seem to be installed. Installing the profiles anyway."
  elif ! version_ge "$app_v" "$IGLASS_MIN_ITERM"; then
    ui_warn "iTerm2 $app_v is older than $IGLASS_MIN_ITERM; light/dark colors won't switch automatically."
  fi

  profile_installed || first=1
  profile_write "$opts"
  state_update '.version = $v | .installedAt = $t | .options = ($o + {variant: $variant})' \
    --arg v "$IGLASS_VERSION" --arg t "$(now_iso)" --argjson o "$opts" --arg variant "$OPT_VARIANT"

  selected=$OPT_VARIANT
  [[ "$(jq -r '.custom != null' <<<"$opts")" == true ]] && selected=custom
  ui_ok "$([[ $first == 1 ]] && echo Installed || echo Updated) iglass for iTerm2 ($(install_summary "$opts"))."
  accessibility_hints "$OPT_VARIANT" "${OPT_CONTRAST:-standard}"

  if [[ $OPT_DEFAULT == 1 ]]; then
    default_guid=$(variant_guid "$selected")
  fi
  if [[ $OPT_APP == 1 || -n "$default_guid" ]]; then
    appsettings_apply "$OPT_APP" "$default_guid"
  elif [[ $first == 1 ]]; then # tips once, not on every tweak
    ui_dim "  Try it: iglass preview$( [[ $selected != frosted ]] && printf ' --variant %s' "$selected")"
    [[ -n "$(appsettings_status)" ]] ||
      ui_dim "  For the full native look add --app-settings (native title bar, roomier padding)."
  fi
}

# One line describing what was installed, e.g. "pink accent, custom opacity 0.6".
install_summary() { # OPTIONS_JSON
  jq -r '[
      "\(.accent) accent",
      (if .contrast == "high" then "high contrast" else empty end),
      (if (.appearance // "auto") != "auto" then "always \(.appearance)" else empty end),
      (if .custom.overrides.transparency != null
       then "custom opacity \((1 - .custom.overrides.transparency) * 100 | round / 100)" else empty end),
      (if .custom.overrides.blurRadius != null then "custom blur \(.custom.overrides.blurRadius)" else empty end)
    ] | join(", ")' <<<"$1"
}

_install_ghostty() {
  local opts=$1 v
  if ! ghostty_present; then
    is_linux && ! kitty_present && die "On Linux iglass works with Ghostty and kitty, and neither is installed." \
      "Get Ghostty from https://ghostty.org/download or kitty from https://sw.kovidgoyal.net/kitty/"
    die "Ghostty is not installed." "Get it from https://ghostty.org"
  fi
  v=$(ghostty_version)
  if [[ -n "$v" ]] && ! version_ge "$v" "$IGLASS_MIN_GHOSTTY"; then
    ui_warn "Ghostty $v is older than $IGLASS_MIN_GHOSTTY; light/dark switching may not work."
  fi
  ghostty_install "$(ghostty_options_json "$opts")"
  accessibility_hints "$OPT_VARIANT" "${OPT_CONTRAST:-standard}"
}

_install_kitty() {
  local opts=$1
  kitty_present || die "kitty is not installed." "Get it from https://sw.kovidgoyal.net/kitty/"
  if [[ "$OPT_GLASS" == native && "$OPT_TERMINAL" == kitty ]]; then
    ui_info "kitty has no Liquid Glass material; iglass uses kitty's own blur."
  fi
  kitty_install "$(kitty_options_json "$opts")"
  accessibility_hints "$OPT_VARIANT" "${OPT_CONTRAST:-standard}"
}

cmd_export() {
  local terminal
  parse_look_options 0 "$@"
  terminal=$OPT_TERMINAL
  if [[ -z "$terminal" ]]; then
    if is_linux; then terminal=ghostty; else terminal=iterm2; fi
  fi
  case "$terminal" in
    iterm2)
      [[ -z "$OPT_DIR" ]] || die "--dir is for Ghostty and kitty, which use several files." "Add --terminal ghostty or --terminal kitty."
      profile_build "$(look_options_json)"
      ;;
    ghostty)
      [[ -n "$OPT_DIR" ]] || die "Ghostty uses several files; pass a folder with --dir." \
        "Example: iglass export --terminal ghostty --dir ./iglass-ghostty"
      ghostty_export_dir "$(ghostty_options_json "$(look_options_json)")" "$OPT_DIR"
      ui_ok "Wrote Ghostty themes and iglass.ghostty to $OPT_DIR"
      ;;
    kitty)
      [[ -n "$OPT_DIR" ]] || die "kitty uses several files; pass a folder with --dir." \
        "Example: iglass export --terminal kitty --dir ./iglass-kitty"
      kitty_export_dir "$(kitty_options_json "$(look_options_json)")" "$OPT_DIR"
      ui_ok "Wrote iglass.conf and kitty's light/dark theme files to $OPT_DIR"
      ;;
    *) die "export handles one terminal at a time." "Use --terminal iterm2, ghostty or kitty." ;;
  esac
}

cmd_preview() {
  local variant="" name
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --variant) _need_value "$@"; variant=$2; shift 2 ;;
      --terminal) _need_value "$@"; OPT_TERMINAL=$2; shift 2 ;;
      *) die "Unknown option: $1" "Usage: iglass preview [--variant clear|frosted|tinted|solid|custom] [--terminal iterm2|ghostty|kitty]" ;;
    esac
  done
  _validate_terminal_option
  case "$(resolve_terminals detect)" in
    ghostty) _preview_ghostty "$variant"; return ;;
    kitty) _preview_kitty "$variant"; return ;;
    *" "*) die "preview opens one terminal at a time." "Use --terminal iterm2, ghostty or kitty." ;;
  esac
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

_preview_ghostty() { # VARIANT
  local variant=$1
  [[ -n "$(state_get '.ghostty.installedAt')" ]] ||
    die "iglass is not installed for Ghostty." "Run: iglass install --terminal ghostty"
  if [[ -z "$variant" ]]; then
    variant=$(state_get 'if .ghostty.options.custom then "custom" else .ghostty.options.variant end')
  fi
  if [[ "$variant" == custom ]]; then
    [[ -f "$(ghostty_themes_dir)/iglass-custom-dark" ]] ||
      die "No custom theme is installed." "Create one with: iglass install --terminal ghostty --opacity 0.8"
  elif [[ -z "$(palette_query '.variants[$v].name // empty' --arg v "$variant")" ]]; then
    die "Unknown variant: $variant" "Choose one of: $(palette_query '.variantOrder | join(" ")') custom"
  fi
  ghostty_preview "$variant" "$(state_get '.ghostty.options.appearance // "auto"')"
  ui_ok "Opened a Ghostty window with iglass $variant."
}

_preview_kitty() { # VARIANT
  local variant=$1 opts
  [[ -n "$(state_get '.kitty.installedAt')" ]] ||
    die "iglass is not installed for kitty." "Run: iglass install --terminal kitty"
  opts=$(state_get '.kitty.options')
  if [[ -z "$variant" ]]; then
    variant=$(jq -r 'if .custom then "custom" else .variant end' <<<"$opts")
  elif [[ "$variant" == custom ]]; then
    [[ "$(jq -r '.custom != null' <<<"$opts")" == true ]] ||
      die "No custom settings are installed." "Create them with: iglass install --terminal kitty --opacity 0.8"
  elif [[ -n "$(palette_query '.variants[$v].name // empty' --arg v "$variant")" ]]; then
    opts=$(jq --arg v "$variant" '. + {variant: $v, custom: null}' <<<"$opts")
  else
    die "Unknown variant: $variant" "Choose one of: $(palette_query '.variantOrder | join(" ")') custom"
  fi
  kitty_preview "$opts"
  ui_ok "Opened a kitty window with iglass $variant."
}

cmd_list() {
  local installed_variant="" installed_accent="" k
  if is_linux; then
    installed_variant=$(state_get '(.ghostty.options // .kitty.options).variant')
    installed_accent=$(state_get '(.ghostty.options // .kitty.options).accent')
  elif profile_installed; then
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

_status_iterm2() {
  local status
  ui_title "iTerm2"
  if profile_installed; then
    ui_ok "Installed $(state_get '.installedAt')"
    state_read | jq -r '.options // {} |
      "  variant \(.variant // "?") · accent \(.accent // "?") · contrast \(.contrast // "standard") · appearance \(.appearance // "auto")",
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
  echo
}

cmd_status() {
  ui_title "iglass $IGLASS_VERSION"
  if is_macos; then _status_iterm2; fi
  ui_title "Ghostty"
  if [[ -n "$(state_get '.ghostty.installedAt')" ]]; then
    ui_ok "Installed $(state_get '.ghostty.installedAt')"
    state_read | jq -r '.ghostty.options // {} |
      "  variant \(if .custom then "custom (\(.custom.base))" else .variant end) · accent \(.accent) · contrast \(.contrast) · appearance \(.appearance // "auto")",
      "  glass \(if .glass == "native" then "real Liquid Glass" else "blur" end) · cursor \(.cursor) · font \(.fontFamily // "your own")"'
    if [[ -n "$(state_get '.ghostty.config')" ]]; then
      ui_dim "  included from $(state_get '.ghostty.config')"
    else
      ui_warn "Not included from your Ghostty config yet; see: iglass doctor"
    fi
  else
    ui_info "Not installed."
  fi
  echo
  ui_title "kitty"
  if [[ -n "$(state_get '.kitty.installedAt')" ]]; then
    ui_ok "Installed $(state_get '.kitty.installedAt')"
    state_read | jq -r '.kitty.options // {} |
      "  variant \(if .custom then "custom (\(.custom.base))" else .variant end) · accent \(.accent) · contrast \(.contrast) · appearance \(.appearance // "auto")",
      "  cursor \(.cursor) · font \(.fontFamily // "your own")"'
    if [[ -n "$(state_get '.kitty.config')" ]]; then
      ui_dim "  included from $(state_get '.kitty.config')"
    else
      ui_warn "Not included from your kitty config yet; see: iglass doctor"
    fi
  else
    ui_info "Not installed."
  fi
  echo
  # Versions of what's installed, e.g. "iTerm2 3.7.4 · kitty 0.49.2 · macOS 27.0.1".
  local versions="" v
  v=$(iterm_version); [[ -n "$v" ]] && versions+="iTerm2 $v · "
  v=$(ghostty_version); [[ -n "$v" ]] && versions+="Ghostty $v · "
  v=$(kitty_version); [[ -n "$v" ]] && versions+="kitty $v · "
  ui_dim "$versions$(os_description)"
}

cmd_uninstall() {
  local restore=ask
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --restore-app-settings) restore=yes; shift ;;
      --keep-app-settings) restore=no; shift ;;
      --terminal) _need_value "$@"; OPT_TERMINAL=$2; shift 2 ;;
      *) die "Unknown option: $1" "Usage: iglass uninstall [--terminal NAME] [--restore-app-settings | --keep-app-settings]" ;;
    esac
  done
  _validate_terminal_option
  local terminals
  terminals=$(resolve_terminals all)
  if [[ " $terminals " == *" ghostty "* ]]; then
    ghostty_uninstall
  fi
  if [[ " $terminals " == *" kitty "* ]]; then
    kitty_uninstall
  fi
  [[ " $terminals " == *" iterm2 "* ]] || return 0

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
