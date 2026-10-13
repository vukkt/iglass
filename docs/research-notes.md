# Research notes

What we verified before writing code, and why iglass is built the way it is.
Verified on macOS 27.0.1 with iTerm2 3.7.4 (October 2026).

## Can iTerm2 use real Liquid Glass?

No, not from a theme. A pull request that added a per-profile "Blur Style → Liquid Glass" option
([gnachman/iTerm2#767](https://github.com/gnachman/iTerm2/pull/767)) was closed without merging.
The maintainer's reason: hosting `NSGlassEffectView` in a terminal window forces Auto Layout,
which breaks window resizing. iTerm2 3.7.4 contains internal glass-view code but exposes no
setting for it (there is no `Blur Style` key in the shipped binary).

There is a second reason not to depend on it today: on macOS 27, an `NSGlassEffectView` tinted
with a dark, near-opaque color renders as a solid fill
([manaflow-ai/cmux#5860](https://github.com/manaflow-ai/cmux/issues/5860)), and dark terminal
backgrounds are exactly that.

iglass therefore builds the look from what iTerm2 supports reliably: window transparency,
background blur, and a palette tuned to stay readable on top of them.

## Profile keys

Confirmed against `sources/Settings/Profiles/ITAddressBookMgr.h` and real preferences.

| Key | Type | Notes |
|---|---|---|
| `Transparency` | real 0–1 | 0 = opaque. iglass's `--opacity` is `1 - Transparency`. |
| `Blur`, `Blur Radius` | bool, real 0–64 | iTerm2 warns above 26 (slow on some machines). |
| `Initial Use Transparency` | bool | New sessions start transparent. |
| `Only The Default BG Color Uses Transparency` | bool | Keeps colored backgrounds (vim, htop) solid. |
| `Minimum Contrast` | real 0–1 | iTerm2 raises text contrast at render time. |
| `Use Separate Colors for Light and Dark Mode` | bool | Enables the `… (Light)` / `… (Dark)` color keys. |
| `Cursor Type` | int | 0 underline, 1 vertical bar, 2 box (`iTermCursor.h`). |
| `Cursor Smooth Slide`, `Cursor Smooth Blink`, `Cursor Shadow` | bool | |
| `Window Type` | int | 0 normal, 12 no title bar, 13 compact. The Minimal theme turns normal into compact. |

Colors are dictionaries of `Red/Green/Blue/Alpha Component` (0–1) plus `Color Space`
(`sRGB` or `P3`). iglass uses `sRGB` so Apple's published system-color values carry over exactly.

## App-wide (global) settings

These live in `com.googlecode.iterm2` and cannot be set by a profile
(`sources/Settings/iTermPreferences.m`):

| Key | Default | iglass `--app-settings` |
|---|---|---|
| `TabStyleWithAutomaticOption` | 0 | 5 (Minimal) |
| `TerminalMargin` (side padding) | 5 | more generous padding |
| `TerminalVMargin` (top/bottom) | 2 | more generous padding |

iTerm2 writes its preferences back when it quits, so global values must be changed while it is
not running. If `LoadPrefsFromCustomFolder` is set, iTerm2 reads preferences from a different
place and iglass refuses to write global settings.

## Dynamic profiles

- JSON files in `~/Library/Application Support/iTerm2/DynamicProfiles/`, reloaded live.
- Each profile needs a `Name` and a unique `Guid`. iglass uses fixed GUIDs, so reinstalling
  updates profiles in place instead of duplicating them.
- Keys a profile leaves out are inherited from the user's default profile, so iglass sets only
  appearance keys. Keyboard maps, shell, working directory and font stay the user's own.
- **One malformed file in the folder stops iTerm2 from loading every dynamic profile.**
  iglass writes atomically (temporary file → `plutil -lint` → rename), and `iglass doctor`
  lints every file in the folder.

## Restarting iTerm2 safely

The installer usually runs *inside* iTerm2, so it cannot quit iTerm2 and keep running. iglass
hands the apply step to launchd with `launchctl submit`. The job's parent is launchd (`ppid=1`),
not iTerm2. launchd restarts submitted jobs that exit with failure, so the helper always exits 0
and removes its own label when done.

## Fonts

SF Mono ships inside `Terminal.app/Contents/Resources/Fonts/` but is not installed system-wide
by default, and Apple's license does not allow redistributing it. iglass keeps the user's font by
default. Many users rely on Nerd Fonts for prompt icons, and replacing the font would break those.
`--font` is opt-in. Font availability is checked through `NSFont` with JavaScript for Automation.
