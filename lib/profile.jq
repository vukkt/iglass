# Builds the iTerm2 Dynamic Profiles document for iglass.
#
# Inputs:
#   $palette  palette data (data/palette.json), passed with --slurpfile
#   $o        options, passed with --argjson: {accent, contrast, cursor, window, font, custom}
#       contrast: "standard" | "high"
#       cursor: "bar" | "box" | "underline" | "keep"
#       window: "native" | "no-titlebar" | "keep"
#       font:   null | "PostScriptName Size"
#       custom: null | {base: <variant>, overrides: {transparency?, blur?, blurRadius?}}
#
# A dynamic profile inherits every key it leaves out from the user's default profile. iglass
# sets every color key, and every key iTerm2 keeps separately for light and dark mode, so
# nothing from the user's old theme can leak into either appearance. Keys about how the user
# works (keyboard, shell, font unless asked) are left alone on purpose.

$palette[0] as $p |
(if $o.contrast == "high" then $p.highContrast else $p end) as $colors |

def suffixed($sfx): with_entries(.key += $sfx);

# Settings iTerm2 stores per appearance (plain, " (Light)", " (Dark)").
def modal($mode; $variant):
  $colors.modes[$mode]
  + $colors.accents[$o.accent][$mode]
  + {
      "Minimum Contrast": $variant.minimumContrast,
      "Faint Text Alpha": 0.55,
      "Use Bright Bold": true,
      "Brighten Bold Text": true,
      "Use Selected Text Color": false,
      "Use Underline Color": false,
      "Use Tab Color": false,
      "Use Cursor Guide": false,
      "Use Active Pane Border": false,
      "Smart Cursor Color": false,
      "Cursor Boost": 0,
      "HDR Cursor": false, # so "HDR Cursor Brightness" has no effect and is left alone
      "Harmonize 256 Colors": false
    };

def cursor_keys:
  if $o.cursor == "keep" then {}
  else {
    "Cursor Type": {"underline": 0, "bar": 1, "box": 2}[$o.cursor],
    "Blinking Cursor": true,
    "Cursor Smooth Blink": true,
    "Cursor Smooth Slide": true
  } end;

def window_keys:
  if $o.window == "keep" then {}
  else {"Window Type": {"native": 0, "no-titlebar": 12}[$o.window]} end;

def font_keys:
  if $o.font then {"Normal Font": $o.font} else {} end;

def profile($name; $guid; $variant):
  {"Name": $name, "Guid": $guid, "Tags": ["iglass"]}
  + modal("dark"; $variant)
  + (modal("dark"; $variant) | suffixed(" (Dark)"))
  + (modal("light"; $variant) | suffixed(" (Light)"))
  + {
      "Use Separate Colors for Light and Dark Mode": true,
      "Background Image Location": "",
      "Transparency": $variant.transparency,
      "Initial Use Transparency": true,
      "Only The Default BG Color Uses Transparency": true,
      "Blur": $variant.blur,
      "Blur Radius": $variant.blurRadius
    }
  + cursor_keys
  + window_keys
  + font_keys;

{
  "Profiles": (
    [ $p.variantOrder[] as $k | $p.variants[$k] as $v | profile($v.name; $v.guid; $v) ]
    + if $o.custom == null then []
      else [ ($p.variants[$o.custom.base] + $o.custom.overrides) as $v
             | profile($p.custom.name; $p.custom.guid; $v) ]
      end
  )
}
