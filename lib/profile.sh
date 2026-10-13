# shellcheck shell=bash
# Building, validating and writing the iglass dynamic profiles file.

# palette_query FILTER [jq args...] — read from the palette data.
palette_query() {
  local filter=$1
  shift
  jq -r "$@" "$filter" "$IGLASS_PALETTE"
}

# profile_build OPTIONS_JSON — print the Dynamic Profiles document.
profile_build() {
  jq -n --slurpfile palette "$IGLASS_PALETTE" --argjson o "$1" -f "$IGLASS_ROOT/lib/profile.jq"
}

# profile_valid FILE — true when FILE parses with Apple's property-list parser (the one iTerm2
# relies on) and has the shape of a Dynamic Profiles document. A single unreadable file in the
# folder stops iTerm2 from loading every dynamic profile, so nothing unvalidated is written.
profile_valid() {
  plutil -convert xml1 -o /dev/null -- "$1" >/dev/null 2>&1 || return 1
  jq -e '
    (.Profiles | type == "array" and length > 0)
    and all(.Profiles[]; (.Name | type == "string") and (.Guid | type == "string"))
  ' "$1" >/dev/null 2>&1
}

# plist_readable FILE — true when Apple's parser can read FILE (any plist format, or JSON).
plist_readable() {
  plutil -convert xml1 -o /dev/null -- "$1" >/dev/null 2>&1
}

# profile_write OPTIONS_JSON — build, validate and atomically replace the iglass profiles file.
profile_write() {
  local tmp
  mkdir -p "$IGLASS_STATE_DIR" "$IGLASS_DYNPROFILES_DIR" 2>/dev/null ||
    die "Could not create $IGLASS_DYNPROFILES_DIR." "Check that you own ~/Library/Application Support."
  [[ -w "$IGLASS_DYNPROFILES_DIR" ]] ||
    die "No permission to write to $IGLASS_DYNPROFILES_DIR."
  # The temporary file lives outside the profiles folder: iTerm2 would try to load a
  # half-written file there.
  tmp=$(mktemp "$IGLASS_STATE_DIR/.iglass.json.XXXXXX") || die "Could not create a temporary file."
  if ! profile_build "$1" >"$tmp" || ! profile_valid "$tmp"; then
    rm -f "$tmp"
    die "Internal error: the generated profile did not validate. Nothing was changed." \
      "Please report this at https://github.com/vukkt/iglass/issues"
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$IGLASS_PROFILE_FILE" || {
    rm -f "$tmp"
    die "Could not write $IGLASS_PROFILE_FILE."
  }
}

# profile_is_ours FILE — true when FILE is a profiles document containing iglass GUIDs.
profile_is_ours() {
  local guids
  guids=$(palette_query '[.variants[].guid, .custom.guid]' -c)
  jq -e --argjson g "$guids" '[.Profiles[]?.Guid] | any(. as $x | $g | index($x))' "$1" >/dev/null 2>&1
}

profile_installed() {
  [[ -f "$IGLASS_PROFILE_FILE" ]] && profile_is_ours "$IGLASS_PROFILE_FILE"
}

# variant_profile_name VARIANT — the iTerm2 profile name for a variant, or for "custom".
variant_profile_name() {
  if [[ "$1" == custom ]]; then
    palette_query '.custom.name'
  else
    palette_query '.variants[$v].name' --arg v "$1"
  fi
}

variant_guid() {
  if [[ "$1" == custom ]]; then
    palette_query '.custom.guid'
  else
    palette_query '.variants[$v].guid' --arg v "$1"
  fi
}
