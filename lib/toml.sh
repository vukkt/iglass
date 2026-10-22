# shellcheck shell=bash
# Line-level edits to a TOML settings file (Warp's settings.toml) that keep everything else
# exactly as the user wrote it: comments, order, spacing and unrelated settings.
#
# A setting is addressed as TABLE KEY, e.g. "appearance.window" "override_opacity", and is
# edited where it's written the usual way: a `key = value` line under a [table] header, which is
# how Warp writes the file. Other spellings of the same settings (a dotted key such as
# `window.override_opacity` under [appearance], or an inline table) are never edited:
# toml_layout_problem finds them, so iglass doesn't write a second, conflicting copy.

# The awk function every pass shares. For each line, parse() sets `kind` (header, key, cont for
# the rest of a multi-line value: a string, an array, or an inline table, which TOML 1.1 lets
# span lines), `table` (the table in effect) and `key`.
TOML_AWK_PARSE='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function unquote(s) { gsub(/["'"'"']/, "", s); return s }
function count(s, pat,   n) { n = 0; while (match(s, pat)) { n++; s = substr(s, RSTART + RLENGTH) } return n }
function parse(l,   v, h, arr) {
  if (in_ml != "") {                       # inside a multi-line string
    kind = "cont"
    if (count(l, in_ml) % 2 == 1) in_ml = ""
    return
  }
  if (depth > 0) {                         # inside a multi-line array or inline table
    kind = "cont"
    depth += count(l, "[[{]") - count(l, "[]}]")
    return
  }
  if (l ~ /^[ \t]*\[/) {
    kind = "header"
    h = l
    sub(/#.*$/, "", h)
    arr = (h ~ /^[ \t]*\[\[/)
    gsub(/\[/, "", h)
    gsub(/\]/, "", h)
    gsub(/[ \t]/, "", h)
    h = unquote(h)
    table = arr ? "[[" h "]]" : h
    key = ""
    return
  }
  if (l ~ /^[ \t]*[A-Za-z0-9_."'"'"'-][^=]*=/) {
    kind = "key"
    key = l
    sub(/=.*/, "", key)
    key = trim(key)
    gsub(/[ \t]*\.[ \t]*/, ".", key)
    key = unquote(key)
    v = l
    sub(/^[^=]*=[ \t]*/, "", v)
    if (count(v, "\"\"\"") % 2 == 1) in_ml = "\"\"\""
    else if (count(v, "'"'''"'") % 2 == 1) in_ml = "'"'''"'"
    else if (v ~ /^[[{]/) depth = count(v, "[[{]") - count(v, "[]}]")
    return
  }
  kind = "other"
}
'

# toml_layout_problem FILE TABLE… — print the first line that sets something in one of these
# tables from outside it (a dotted key or an inline table), or nothing.
toml_layout_problem() {
  local file=$1
  shift
  [[ -f "$file" ]] || return 0
  awk -v tables="$*" "$TOML_AWK_PARSE"'
    BEGIN { n = split(tables, t, " ") }
    {
      parse($0)
      if (kind != "key") next
      full = (table == "" ? key : table "." key)
      for (i = 1; i <= n; i++)
        if (table != t[i] && (full == t[i] || index(full, t[i] ".") == 1 || index(t[i], full ".") == 1)) {
          print $0
          exit
        }
    }' "$file"
}

# toml_get FILE TABLE KEY — print the line that sets KEY in TABLE, or nothing.
toml_get() {
  [[ -f "$1" ]] || return 0
  awk -v want_table="$2" -v want_key="$3" "$TOML_AWK_PARSE"'
    { parse($0); if (kind == "key" && table == want_table && key == want_key) { print $0; exit } }' "$1"
}

# toml_edit FILE OUT EDITS — write FILE, with the edits applied, to OUT. FILE may be missing.
# EDITS is a file of tab-separated lines:
#   set    TABLE KEY LINE   replace the line that sets KEY (and the rest of a multi-line value),
#                           or add LINE at the end of TABLE, or add TABLE at the end of the file
#   unset  TABLE KEY        remove the line that sets KEY
#   drop   TABLE            remove TABLE's header, and the blank line before it, when nothing
#                           but blank lines is left in it (for tables iglass added)
toml_edit() {
  local src=$1
  [[ -f "$src" ]] || src=/dev/null
  awk -v edits="$3" "$TOML_AWK_PARSE"'
    BEGIN {
      while ((getline e < edits) > 0) {
        ne++
        split(e, f, "\t")
        op[ne] = f[1]; et[ne] = f[2]; ek[ne] = f[3]
        el[ne] = substr(e, length(f[1] f[2] f[3]) + 4)
      }
    }
    {
      n++; line[n] = $0
      parse($0)
      kd[n] = kind
      if (kind == "header") hdr[table] = n
      if (kind == "key" || kind == "cont") last_in[table] = n
      if (kind == "key") at[table SUBSEP key] = n
    }
    END {
      for (i = 1; i <= ne; i++) {
        k = et[i] SUBSEP ek[i]
        if (op[i] == "set") {
          if (k in at) {
            j = at[k]
            line[j] = el[i]
            for (m = j + 1; m <= n && kd[m] == "cont"; m++) gone[m] = 1
          } else if (et[i] in hdr) {
            j = (et[i] in last_in) ? last_in[et[i]] : hdr[et[i]]
            after[j] = after[j] el[i] "\n"
          } else {
            if (!(et[i] in newtab)) { newtab[et[i]] = ++nt; tname[nt] = et[i] }
            tbody[et[i]] = tbody[et[i]] el[i] "\n"
          }
        } else if (op[i] == "unset") {
          if (k in at) {
            j = at[k]
            gone[j] = 1
            for (m = j + 1; m <= n && kd[m] == "cont"; m++) gone[m] = 1
          }
        } else if (op[i] == "drop") {
          drop[et[i]] = 1
        }
      }
      for (t in drop) {
        if (!(t in hdr)) continue
        j = hdr[t]
        if (j in after) continue
        empty = 1
        for (m = j + 1; m <= n && kd[m] != "header"; m++)
          if (!(m in gone) && line[m] !~ /^[ \t]*$/) { empty = 0; break }
        if (!empty) continue
        gone[j] = 1
        for (m = j + 1; m <= n && kd[m] != "header"; m++) gone[m] = 1
        if (j > 1 && line[j - 1] ~ /^[ \t]*$/ && !((j - 1) in gone)) gone[j - 1] = 1
      }
      out = ""
      for (i = 1; i <= n; i++) {
        if (!(i in gone)) out = out line[i] "\n"
        if (i in after) out = out after[i]
      }
      for (i = 1; i <= nt; i++) {
        if (out != "" && out !~ /\n\n$/) out = out "\n"
        out = out "[" tname[i] "]\n" tbody[tname[i]]
      }
      printf "%s", out
    }' "$src" >"$2"
}
