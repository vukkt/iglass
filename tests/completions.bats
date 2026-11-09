#!/usr/bin/env bats
# Shell completions (completions/): what bash, zsh and fish offer when Tab is pressed, and that
# they keep up with the options the command line accepts. zsh and fish are tested when they
# are installed (CI installs both).

load helpers

setup() {
  setup_sandbox
  COMPLETIONS="$REPO_ROOT/completions"
}

# bash_complete WORD… — the candidates bash offers for the last word, sorted, on one line.
bash_complete() {
  # shellcheck source=completions/iglass.bash
  source "$COMPLETIONS/iglass.bash"
  COMP_WORDS=("$@")
  COMP_CWORD=$(($# - 1))
  _iglass
  printf '%s\n' ${COMPREPLY[@]+"${COMPREPLY[@]}"} | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

# zsh_complete LINE — the same for zsh, which completes LINE in a real (pseudo-)terminal.
zsh_complete() {
  zsh -f "$REPO_ROOT/tests/complete.zsh" "$COMPLETIONS" "$1" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

# fish_complete LINE — the same for fish.
fish_complete() {
  fish --no-config -c "source '$COMPLETIONS/iglass.fish'; complete -C '$1'" | cut -f1 |
    LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'
}

@test "bash: commands, options per command, and their values" {
  run bash_complete iglass ""
  [[ "$output" == "--help --version --yes doctor export help install list preview status uninstall" ]] || false
  run bash_complete iglass install --a
  [[ "$output" == "--accent --app-settings --appearance" ]] || false
  run bash_complete iglass -y install --accent ""
  [[ "$output" == "blue graphite green orange pink purple red yellow" ]] || false
  run bash_complete iglass preview --variant ""
  [[ "$output" == "clear custom frosted solid tinted" ]] || false
  run bash_complete iglass install --variant ""
  [[ "$output" == "clear frosted solid tinted" ]] || false
  run bash_complete iglass export --terminal ""
  [[ "$output" == "ghostty iterm2 kitty warp" ]] || false
  run bash_complete iglass uninstall --
  [[ "$output" == "--help --keep-app-settings --restore-app-settings --terminal --yes" ]] || false
  run bash_complete iglass install --opacity ""
  [[ -z "$output" ]] || false
  run bash_complete iglass status --
  [[ "$output" == "--help" ]] || false
}

@test "bash: --dir offers folders" {
  mkdir -p "$SANDBOX/out/themes dir" "$SANDBOX/out/other"
  touch "$SANDBOX/out/a-file"
  cd "$SANDBOX/out"
  run bash_complete iglass export --terminal kitty --dir ""
  [[ "$output" == "other themes dir" ]] || false
}

@test "bash: every value offered is one iglass accepts" {
  local opt value
  for opt in --variant --accent --contrast --appearance --cursor --window --font --glass; do
    for value in $(bash_complete iglass export --terminal iterm2 "$opt" ""); do
      run "$IGLASS" export --terminal iterm2 "$opt" "$value"
      [[ $status == 0 ]] || { echo "rejected: $opt $value: $output"; false; }
    done
  done
}

@test "zsh: commands, options per command, and their values" {
  command -v zsh >/dev/null || skip "zsh is not installed"
  run zsh -n "$COMPLETIONS/_iglass"
  assert_success_
  run zsh_complete 'iglass '
  [[ "$output" == "doctor export help install list preview status uninstall" ]] || false
  run zsh_complete 'iglass install --a'
  [[ "$output" == "--accent --app-settings --appearance" ]] || false
  run zsh_complete 'iglass -y install --accent '
  [[ "$output" == "blue graphite green orange pink purple red yellow" ]] || false
  run zsh_complete 'iglass preview --variant '
  [[ "$output" == "clear custom frosted solid tinted" ]] || false
  run zsh_complete 'iglass export --terminal '
  [[ "$output" == "ghostty iterm2 kitty warp" ]] || false
  run zsh_complete 'iglass uninstall --'
  [[ "$output" == "--help --keep-app-settings --restore-app-settings --terminal --yes" ]] || false
}

@test "fish: commands, options per command, and their values" {
  command -v fish >/dev/null || skip "fish is not installed"
  run fish --no-config --no-execute "$COMPLETIONS/iglass.fish"
  assert_success_
  run fish_complete 'iglass '
  [[ "$output" == "doctor export help install list preview status uninstall" ]] || false
  run fish_complete 'iglass install --a'
  [[ "$output" == "--accent --app-settings --appearance" ]] || false
  run fish_complete 'iglass -y install --accent '
  [[ "$output" == "blue graphite green orange pink purple red yellow" ]] || false
  run fish_complete 'iglass preview --variant '
  [[ "$output" == "clear custom frosted solid tinted" ]] || false
  run fish_complete 'iglass export --terminal '
  [[ "$output" == "ghostty iterm2 kitty warp" ]] || false
  run fish_complete 'iglass uninstall --'
  [[ "$output" == "--help --keep-app-settings --restore-app-settings --terminal --yes" ]] || false
}

@test "every option the command line accepts is completed in all three shells" {
  local opts opt
  # The option patterns of the parsers in lib/commands.sh, e.g. "    --accent)" or "--a | --b)".
  opts=$(grep -oE '^ +--[a-z-]+( \| --[a-z-]+)*\)' "$REPO_ROOT/lib/commands.sh" | grep -oE -- '--[a-z-]+' | sort -u)
  [[ $(wc -l <<<"$opts") -ge 17 ]] || { echo "found only: $opts"; false; }
  for opt in $opts --help --version --yes; do
    grep -qE -- "[ \"]$opt( |\"|$)" "$COMPLETIONS/iglass.bash" || { echo "bash lacks $opt"; false; }
    grep -qE -- "$opt(\[|\})" "$COMPLETIONS/_iglass" || { echo "zsh lacks $opt"; false; }
    grep -qE -- "-l ${opt#--}( |$)" "$COMPLETIONS/iglass.fish" || { echo "fish lacks $opt"; false; }
  done
}

@test "the completions list the palette's variants and accents, in order" {
  local variants accents f
  variants=$(jq -r '.variantOrder | join(" ")' "$REPO_ROOT/data/palette.json")
  accents=$(jq -r '.accentOrder | join(" ")' "$REPO_ROOT/data/palette.json")
  for f in iglass.bash _iglass iglass.fish; do
    grep -qF -- "$variants" "$COMPLETIONS/$f" || { echo "$f: variants aren't $variants"; false; }
    grep -qF -- "$accents" "$COMPLETIONS/$f" || { echo "$f: accents aren't $accents"; false; }
  done
}
