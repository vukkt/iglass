# shellcheck shell=bash
# shellcheck disable=SC2034  # CONFIGFILE_ADDED_NEWLINE is read by the terminal modules
# Safe edits to a terminal's own config file, shared by every terminal iglass supports.
#
# iglass adds exactly two lines to the end of the user's config: a marker comment and an
# include line, after a blank line. Removing them restores the file byte for byte, including a
# missing final newline. Symlinked dotfiles stay symlinks, permissions are kept, every write is
# atomic, and a read-only config (Nix, home-manager) is left alone.

# configfile_rewrite FILE CONTENT_FILE — replace FILE's contents without breaking a symlinked
# dotfile: edit the link's target, keep its permissions, replace it atomically.
configfile_rewrite() {
  local file=$1 content=$2 real dir tmp mode
  real=$file
  if [[ -L "$file" ]]; then
    real=$(cd "$(dirname "$file")" && cd "$(dirname "$(readlink "$file")")" && pwd)/$(basename "$(readlink "$file")")
  fi
  dir=$(dirname "$real")
  tmp=$(mktemp "$dir/.iglass-config.XXXXXX") || return 1
  cat "$content" >"$tmp" || { rm -f "$tmp"; return 1; }
  if [[ -f "$real" ]]; then
    mode=$(file_mode "$real")
    chmod "${mode:-644}" "$tmp"
  else
    chmod 644 "$tmp"
  fi
  mv -f "$tmp" "$real"
}

# configfile_has_include FILE MARKER LINE — true when FILE contains iglass's two lines.
configfile_has_include() {
  [[ -f "$1" ]] && grep -qxF "$2" "$1" && grep -qxF "$3" "$1"
}

# configfile_add_include FILE MARKER LINE BACKUP_NAME — append iglass's lines, backing the file up
# the first time. Sets CONFIGFILE_ADDED_NEWLINE to true, false, or keep (lines already there).
# Returns 1 when the file can't be written.
CONFIGFILE_ADDED_NEWLINE=keep
configfile_add_include() {
  local target=$1 marker=$2 include=$3 backup_name=$4 tmp backup_dir
  CONFIGFILE_ADDED_NEWLINE=keep
  configfile_has_include "$target" "$marker" "$include" && return 0
  CONFIGFILE_ADDED_NEWLINE=false
  mkdir -p "$(dirname "$target")" 2>/dev/null
  if [[ -f "$target" ]]; then
    backup_dir="$IGLASS_STATE_DIR/backups"
    mkdir -p "$backup_dir"
    [[ -f "$backup_dir/$backup_name" ]] || cp "$target" "$backup_dir/$backup_name"
  fi
  mkdir -p "$IGLASS_STATE_DIR"
  tmp=$(mktemp "$IGLASS_STATE_DIR/.config-edit.XXXXXX") || return 1
  if [[ -s "$target" ]]; then
    cat "$target" >"$tmp"
    if [[ -n "$(tail -c 1 "$target")" ]]; then # file lacked a final newline
      printf '\n' >>"$tmp"
      CONFIGFILE_ADDED_NEWLINE=true
    fi
    printf '\n' >>"$tmp"
  fi
  printf '%s\n%s\n' "$marker" "$include" >>"$tmp"
  if [[ ! -w "$(dirname "$target")" ]] || { [[ -e "$target" ]] && [[ ! -w "$target" ]]; } ||
    ! configfile_rewrite "$target" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

# configfile_remove_include FILE MARKER LINE [STRIP_NEWLINE] — remove iglass's two lines and the
# blank line added before them. STRIP_NEWLINE=true drops the final newline iglass added to a
# file that had none, if iglass's lines were last.
configfile_remove_include() {
  local target=$1 marker=$2 include=$3 strip=${4:-false} tmp
  configfile_has_include "$target" "$marker" "$include" || return 0
  tmp=$(mktemp "$IGLASS_STATE_DIR/.config-edit.XXXXXX") || return 1
  # Not "include": that's a reserved word in gawk, the awk on Fedora and Arch.
  if ! awk -v marker="$marker" -v inc="$include" -v strip="$strip" '
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (lines[i] == marker && lines[i + 1] == inc) {
          if (n > 0 && out[n] == "") n--   # the blank separator iglass added
          last = (i + 1 == NR)
          i++
          continue
        }
        out[++n] = lines[i]
        last = 0
      }
      for (i = 1; i <= n; i++) printf "%s%s", out[i], (i < n || !(strip == "true" && last) ? "\n" : "")
    }' "$target" >"$tmp"; then
    rm -f "$tmp" # never replace the user's config with a half-written one
    return 1
  fi
  configfile_rewrite "$target" "$tmp"
  rm -f "$tmp"
}
