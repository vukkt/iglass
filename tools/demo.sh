#!/bin/bash
# Prints a showcase of terminal colors: a prompt, a listing, a diff, logs and the ANSI palette.
# Used for screenshots and for eyeballing a palette. Output is static; nothing is run.

e=$'\033'
r="${e}[0m" b="${e}[1m" d="${e}[2m"
c() { printf '%s[%sm' "$e" "$1"; }

printf '\n'
printf ' %s~/Projects/iglass%s on %s main%s %s✓%s\n' "$(c 36)$b" "$r" "$(c 35)" "$r" "$(c 32)" "$r"
printf ' %s❯%s ls\n' "$(c 32)" "$r"
printf ' %sbin%s  %sdata%s  %sdesign%s  %slib%s  README.md  %sinstall.sh%s\n' \
  "$(c 34)$b" "$r" "$(c 34)$b" "$r" "$(c 34)$b" "$r" "$(c 34)$b" "$r" "$(c 32)$b" "$r"
printf '\n'
printf ' %s❯%s git diff --stat\n' "$(c 32)" "$r"
printf ' %slib/profile.jq%s | 12 %s++++++++%s%s----%s\n' "$b" "$r" "$(c 32)" "$r" "$(c 31)" "$r"
printf ' %s@@ -12,6 +12,8 @@%s %sdef glass($v):%s\n' "$(c 36)" "$r" "$d" "$r"
printf ' %s-  "Transparency": 0.24,%s\n' "$(c 31)" "$r"
printf ' %s+  "Transparency": 0.34,%s\n' "$(c 32)" "$r"
printf ' %s+  "Blur Radius": 24%s\n' "$(c 32)" "$r"
printf '\n'
printf ' %s[info]%s  palette built %s(min safe opacity 0.66)%s\n' "$(c 34)" "$r" "$(c 90)" "$r"
printf ' %s[warn]%s  blur above 26 may be slow\n' "$(c 33)" "$r"
printf ' %s[ok]%s    contrast checks passed\n' "$(c 32)" "$r"
printf ' %s[fail]%s  1 file unreadable in DynamicProfiles\n' "$(c 31)" "$r"
printf ' %s# a muted comment or autosuggestion%s\n' "$(c 90)" "$r"
printf ' %shttps://github.com/vukkt/iglass%s\n' "${e}[4m$(c 34)" "$r"
printf '\n '
for i in 0 1 2 3 4 5 6 7; do printf '%s %d %s' "${e}[48;5;${i}m$(c 97)" "$i" "$r"; done
printf '\n '
for i in 8 9 10 11 12 13 14 15; do printf '%s%3d%s' "${e}[48;5;${i}m$(c 30)" "$i" "$r"; done
printf '\n '
for i in 30 31 32 33 34 35 36 37; do printf '%s ab %s' "$(c "$i")" "$r"; done
printf '\n '
for i in 90 91 92 93 94 95 96 97; do printf '%s ab %s' "$(c "$i")" "$r"; done
printf '\n\n'
