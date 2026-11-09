# fish completion for iglass (https://github.com/vukkt/iglass).
# Homebrew and install.sh install it; to use it from a checkout: source completions/iglass.fish

set -l commands install uninstall preview list status doctor export help
set -l look install export

complete -c iglass -f
complete -c iglass -s h -l help -d 'Show help'
complete -c iglass -s v -l version -n "not __fish_seen_subcommand_from $commands" -d 'Show the version'
complete -c iglass -s y -l yes -d 'Answer yes to questions'

complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a install -d 'Install or update iglass'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a preview -d 'Open a window with an iglass variant'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a list -d 'Show variants and accent colors'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a status -d 'Show what is installed'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a doctor -d 'Check for problems (changes nothing)'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a export -d 'Print or write the theme files'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a uninstall -d 'Remove iglass and undo its changes'
complete -c iglass -n "not __fish_seen_subcommand_from $commands" -a help -d 'Show help'

# Look options (install, export)
complete -c iglass -n "__fish_seen_subcommand_from $look" -l variant -x -a 'clear frosted tinted solid' -d 'Glass level'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l accent -x -a 'blue purple pink red orange yellow green graphite' -d 'Accent color'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l contrast -x -a 'standard high' -d 'Contrast level'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l appearance -x -a 'auto dark light' -d 'Follow light/dark mode, or always one'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l cursor -x -a 'bar box underline keep' -d 'Cursor style'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l window -x -a 'native no-titlebar keep' -d 'Window style'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l font -x -a 'keep sf-mono' -d 'Font'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l opacity -x -d 'Your own opacity, 0.05 to 1'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l blur -x -d 'Your own blur radius, 0 to 64'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l force -d 'Allow an opacity below the readable minimum'
complete -c iglass -n "__fish_seen_subcommand_from $look" -l glass -x -a 'auto native blur' -d 'Ghostty glass'

# Terminals
complete -c iglass -n "__fish_seen_subcommand_from install uninstall" -l terminal -x -a 'iterm2 ghostty kitty warp all' -d 'Terminal'
complete -c iglass -n "__fish_seen_subcommand_from export" -l terminal -x -a 'iterm2 ghostty kitty warp' -d 'Terminal'
complete -c iglass -n "__fish_seen_subcommand_from preview" -l terminal -x -a 'iterm2 ghostty kitty' -d 'Terminal'

# Per command
complete -c iglass -n "__fish_seen_subcommand_from install" -l app-settings -d 'iTerm2: native title bar and roomier padding'
complete -c iglass -n "__fish_seen_subcommand_from install" -l default -d 'iTerm2: make the variant your default profile'
complete -c iglass -n "__fish_seen_subcommand_from export" -l dir -x -a '(__fish_complete_directories)' -d 'Folder to write the files to'
complete -c iglass -n "__fish_seen_subcommand_from preview" -l variant -x -a 'clear frosted tinted solid custom' -d 'Glass level'
complete -c iglass -n "__fish_seen_subcommand_from uninstall" -l restore-app-settings -d "Put back iTerm2's app-wide settings without asking"
complete -c iglass -n "__fish_seen_subcommand_from uninstall" -l keep-app-settings -d "Keep iTerm2's app-wide settings as they are"
