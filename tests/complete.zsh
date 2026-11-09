#!/bin/zsh -f
# Prints what zsh offers when Tab is pressed after a command line, one candidate per line.
# Usage: zsh -f tests/complete.zsh COMPLETIONS_DIR 'iglass install --accent '
#
# zsh only completes inside its line editor, so this starts an interactive zsh in a
# pseudo-terminal (zpty) with a .zshrc that loads the completions from COMPLETIONS_DIR and wraps
# compadd to record every candidate. Then it types the line, presses Tab, and presses a key
# bound to a widget that marks the end.

emulate -L zsh
zmodload zsh/zpty || exit 1
local dir=${1:a} input=$2 home=$(mktemp -d) i x
local out=$home/candidates

cat >$home/.zshrc <<EOF
PROMPT='> '
fpath=(${(q)dir} \$fpath)
autoload -Uz compinit && compinit -u -d ${(q)home}/.zcompdump
zstyle ':completion:*' menu no
compadd() { builtin compadd -O __c "\$@"; print -rl -- \$__c >>${(q)out}; builtin compadd "\$@"; }
__done() { print -r -- __done__ >>${(q)out}; }
zle -N __done
bindkey '^X' __done
EOF

# -d skips the system-wide startup files; HOME and ZDOTDIR keep yours out too.
zpty z env HOME=$home ZDOTDIR=$home zsh -d -i
# Type only once the prompt is up: zsh drops what was typed while it started.
local seen=""
for i in {1..200}; do
  while zpty -r -t z x; do seen+=$x; done
  [[ $seen == *'> '* ]] && break
  sleep 0.05
done
zpty -w -n z "${input}"$'\t\x18'
for i in {1..200}; do
  grep -qx __done__ $out 2>/dev/null && break
  while zpty -r -t z x; do :; done # keep the terminal's output drained
  sleep 0.05
done
zpty -d z
grep -vx -e __done__ -e "" $out | sort -u
rm -rf $home
