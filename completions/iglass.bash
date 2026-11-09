# shellcheck shell=bash
# bash completion for iglass (https://github.com/vukkt/iglass). Works with bash 3.2+.
# Homebrew and install.sh install it; to use it from a checkout: source completions/iglass.bash

_iglass() {
  local cur=${COMP_WORDS[COMP_CWORD]} prev=${COMP_WORDS[COMP_CWORD - 1]} cmd="" i
  local look="--variant --accent --contrast --appearance --cursor --window --font --opacity --blur --force"
  local terminals="iterm2 ghostty kitty warp all" words=""
  COMPREPLY=()

  # The command is the first word that isn't an option (-y, -h and -v go anywhere).
  for ((i = 1; i < COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
      -*) ;;
      *) cmd=${COMP_WORDS[i]}; break ;;
    esac
  done

  case "$cmd" in
    preview) terminals="iterm2 ghostty kitty" ;;
    export) terminals="iterm2 ghostty kitty warp" ;;
  esac
  case "$prev" in
    --terminal) words=$terminals ;;
    --glass) words="auto native blur" ;;
    --variant)
      words="clear frosted tinted solid"
      [[ "$cmd" == preview ]] && words+=" custom"
      ;;
    --accent) words="blue purple pink red orange yellow green graphite" ;;
    --contrast) words="standard high" ;;
    --appearance) words="auto dark light" ;;
    --cursor) words="bar box underline keep" ;;
    --window) words="native no-titlebar keep" ;;
    --font) words="keep sf-mono" ;;
    --opacity | --blur) return 0 ;; # a number
    --dir)
      compopt -o filenames 2>/dev/null || : # bash 4+: add slashes and escape spaces
      local IFS=$'\n'
      # shellcheck disable=SC2207  # folder names, split on newlines only
      COMPREPLY=($(compgen -d -- "$cur"))
      return 0
      ;;
  esac

  if [[ -z "$words" ]]; then
    case "$cmd" in
      "") words="install uninstall preview list status doctor export help --help --version --yes" ;;
      install) words="$look --terminal --glass --app-settings --default --yes --help" ;;
      export) words="$look --terminal --glass --dir --help" ;;
      preview) words="--variant --terminal --help" ;;
      uninstall) words="--terminal --restore-app-settings --keep-app-settings --yes --help" ;;
      *) words="--help" ;;
    esac
  fi
  # shellcheck disable=SC2207  # the words have no spaces
  COMPREPLY=($(compgen -W "$words" -- "$cur"))
}

complete -F _iglass iglass
