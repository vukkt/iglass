# What iglass changes

iglass changes how your terminal looks and nothing about how you work: your font, keyboard
shortcuts, shell and folders stay as they are. Everything it writes is listed here, per
terminal, and `iglass uninstall` takes all of it back out. To see what's installed right now,
run `iglass status`; to check it, `iglass doctor`.

## iTerm2

- One file, `~/Library/Application Support/iTerm2/DynamicProfiles/iglass.json`, with an iTerm2
  [dynamic profile](https://iterm2.com/documentation-dynamic-profiles.html) per variant (and
  **iglass Custom** with `--opacity` or `--blur`). iglass checks it with Apple's own parser
  before writing it, because one unreadable file in that folder stops iTerm2 from loading any
  dynamic profile.
- Your own profiles and settings are untouched, unless you pass one of the two options below.

### App-wide settings (`--app-settings` and `--default`)

Some of the native feel comes from iTerm2 settings that apply to every window, not just a
profile: iTerm2's **Automatic** theme, which lets macOS draw the title bar and tabs the way it
draws them for its own apps, and generous **padding**. Apple's Liquid Glass guidance asks apps
to let the system draw bars rather than custom ones. `--app-settings` turns these on, and
`--default` makes an iglass profile your default one.

Because iTerm2 saves its settings when it quits, iglass has to change them while iTerm2 is
closed:

1. iglass records the current values and backs up your iTerm2 preferences.
2. A small helper quits iTerm2 (it asks first if programs are running), applies the change and
   reopens it. If you cancel the quit, nothing is written.
3. `iglass uninstall` restores the exact previous values and removes keys that didn't exist.
   It asks first; `--restore-app-settings` or `--keep-app-settings` answer for you.

## Ghostty

- Theme files in `~/.config/ghostty/themes/iglass-*`, one per variant and appearance, with the
  colors, opacity and glass.
- `~/.config/ghostty/iglass.ghostty`: which theme to use, padding and cursor.
- Two lines, after a blank line, at the end of your Ghostty config (the one Ghostty loads
  last): a comment and an optional `config-file` include. Your config is backed up first,
  symlinked dotfiles stay symlinks, and `iglass uninstall` restores the file exactly.

iglass checks every file with Ghostty's own validator before anything touches your config.

## kitty

In the folder kitty reads its configuration from (chosen exactly the way kitty chooses it,
usually `~/.config/kitty`):

- `iglass.conf`: opacity, blur, padding and cursor.
- `dark-theme.auto.conf`, `light-theme.auto.conf` and `no-preference-theme.auto.conf`: the
  colors kitty switches between with light and dark mode. If you already have your own (from
  `kitten themes`), iglass sets them aside and puts them back on uninstall.
- Two lines at the end of `kitty.conf`: a comment and `include iglass.conf`. Like Ghostty's,
  backed up first and restored exactly by `iglass uninstall`.

iglass loads every file with kitty's own config parser before anything touches your config.

## Warp

- `iglass-dark.yaml` and `iglass-light.yaml` in Warp's themes folder (`~/.warp/themes` on macOS,
  `~/.local/share/warp-terminal/themes` on Linux): the colors and accent.
- A few settings in Warp's `settings.toml` (`~/.warp/settings.toml` on macOS,
  `~/.config/warp-terminal/settings.toml` on Linux): the theme and following light and dark
  mode (`[appearance.themes]`), window opacity and blur (`[appearance.window]`), the cursor
  unless you pass `--cursor keep`, and the font with `--font`. Every other line, comment and
  setting stays as it was.
- `iglass uninstall` puts back the values you had, removes what iglass added, and leaves alone
  anything you changed in Warp since. If nothing else changed, the file comes back byte for
  byte. iglass checks every setting against the schema Warp ships before writing anything.
- If you use Warp's Settings Sync, Warp syncs these settings to your other computers, like any
  change you make on its settings page.

## iglass's own files

- Its record of what it changed (`state.json`) and the backups of your configs and iTerm2
  preferences live in `~/Library/Application Support/iglass` on macOS and
  `~/.local/state/iglass` on Linux (or `$XDG_STATE_HOME/iglass`).
- While it works, iglass writes to temporary files next to these and swaps them in only when
  they're complete. If it's interrupted (Ctrl-C), it removes them on the way out, so a config is
  never left half-written.
- Tab completion, when you install with Homebrew or the install script: one small file each for
  bash, zsh and fish, in the folders those shells read completions from.
