#!/usr/bin/env bats
# The generated profiles document: validity, completeness and option handling.

load helpers

setup() { setup_sandbox; }

export_to() { # FILE ARGS…
  local out=$1
  shift
  "$IGLASS" export "$@" >"$out"
}

# Every key iTerm2 keeps separately for light and dark mode (from iTermProfilePreferences.m).
# A profile that leaves one out inherits it from the user's default profile, letting their old
# theme leak into iglass.
MODE_KEYS='[
  "Foreground Color","Background Color","Bold Color","Link Color","Match Background Color",
  "Selection Color","Selected Text Color","Cursor Color","Cursor Text Color","IME Cursor Color",
  "Ansi 0 Color","Ansi 1 Color","Ansi 2 Color","Ansi 3 Color","Ansi 4 Color","Ansi 5 Color",
  "Ansi 6 Color","Ansi 7 Color","Ansi 8 Color","Ansi 9 Color","Ansi 10 Color","Ansi 11 Color",
  "Ansi 12 Color","Ansi 13 Color","Ansi 14 Color","Ansi 15 Color","Cursor Guide Color",
  "Badge Color","Tab Color","Underline Color","Active Pane Border Color",
  "Brighten Bold Text","Cursor Boost","Faint Text Alpha","Harmonize 256 Colors","HDR Cursor",
  "Minimum Contrast","Smart Cursor Color","Use Active Pane Border","Use Bright Bold",
  "Use Cursor Guide","Use Selected Text Color","Use Tab Color","Use Underline Color"
]'

@test "every variant and accent produces a valid, complete document" {
  local accents accent f
  accents=$(jq -r '.accentOrder[]' "$REPO_ROOT/data/palette.json")
  for accent in $accents; do
    f="$BATS_TEST_TMPDIR/$accent.json"
    export_to "$f" --accent "$accent" --opacity 0.8 --blur 10
    plutil -convert xml1 -o /dev/null "$f"
    run jq -e --argjson keys "$MODE_KEYS" '
      .Profiles | length == 5 and all(.[];
        . as $p | all($keys[]; . as $k |
          ($p | has($k)) and ($p | has($k + " (Light)")) and ($p | has($k + " (Dark)"))))' "$f"
    if [[ "$status" -ne 0 ]]; then
      echo "accent $accent is missing light/dark keys" >&2
      return 1
    fi
  done
}

@test "the document contains no null values (plists cannot hold them)" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -e '[.. | select(. == null)] | length == 0' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "colors are sRGB components between 0 and 1" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -e '[.Profiles[] | to_entries[] | select(.key | test("Color"))
    | select(.value | type == "object") | .value] | length > 100 and all(
      ."Color Space" == "sRGB"
      and ([."Red Component", ."Green Component", ."Blue Component", ."Alpha Component"]
           | all(type == "number" and . >= 0 and . <= 1)))' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "profiles use the fixed GUIDs and names from the palette" {
  export_to "$BATS_TEST_TMPDIR/p.json" --opacity 0.9
  run jq -e --slurpfile pal "$REPO_ROOT/data/palette.json" '
    [.Profiles[] | {Name, Guid}] == (
      [$pal[0].variantOrder[] as $v | $pal[0].variants[$v] | {Name: .name, Guid: .guid}]
      + [{Name: $pal[0].custom.name, Guid: $pal[0].custom.guid}])' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "light and dark palettes are actually different" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -e '.Profiles[0] | ."Background Color (Light)" != ."Background Color (Dark)"
    and ."Foreground Color (Light)" != ."Foreground Color (Dark)"
    and ."Use Separate Colors for Light and Dark Mode" == true' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "variants carry their glass settings" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -e --slurpfile pal "$REPO_ROOT/data/palette.json" '
    all(.Profiles[]; . as $p | $pal[0].variants[] | select(.guid == $p.Guid)
      | $p.Transparency == .transparency and $p.Blur == .blur
        and $p."Blur Radius" == .blurRadius
        and $p."Minimum Contrast (Dark)" == .minimumContrast)' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "the solid variant is opaque with blur off" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -r '.Profiles[] | select(.Name == "iglass Solid") | "\(.Transparency) \(.Blur)"' "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == "0 false" || "$output" == "0.0 false" ]]
}

@test "transparency only applies to the default background" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -e 'all(.Profiles[]; ."Only The Default BG Color Uses Transparency" == true
    and ."Background Image Location" == "")' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "custom profile is based on --variant with overrides applied" {
  export_to "$BATS_TEST_TMPDIR/p.json" --variant tinted --opacity 0.7 --force
  run jq -r '.Profiles[] | select(.Name == "iglass Custom") | "\(.Transparency) \(.Blur) \(."Blur Radius")"' \
    "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == "0.3 true 26" ]]
}

@test "no custom profile without --opacity or --blur" {
  export_to "$BATS_TEST_TMPDIR/p.json" --variant clear
  run jq -r '[.Profiles[].Name] | index("iglass Custom")' "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == null ]]
}

@test "cursor and window defaults: bar cursor, native window" {
  export_to "$BATS_TEST_TMPDIR/p.json"
  run jq -r '.Profiles[0] | "\(."Cursor Type") \(."Cursor Smooth Slide") \(."Window Type")"' "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == "1 true 0" ]]
}

@test "cursor and window styles map to iTerm2 values" {
  export_to "$BATS_TEST_TMPDIR/p.json" --cursor box --window no-titlebar
  run jq -r '.Profiles[0] | "\(."Cursor Type") \(."Window Type")"' "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == "2 12" ]]
  export_to "$BATS_TEST_TMPDIR/p.json" --cursor underline
  run jq -r '.Profiles[0]."Cursor Type"' "$BATS_TEST_TMPDIR/p.json"
  [[ "$output" == 0 ]]
}

@test "keep leaves cursor, window and font to the user's own profile" {
  export_to "$BATS_TEST_TMPDIR/p.json" --cursor keep --window keep
  run jq -e 'all(.Profiles[]; (has("Cursor Type") or has("Blinking Cursor") or has("Window Type")
    or has("Normal Font")) | not)' "$BATS_TEST_TMPDIR/p.json"
  assert_success_
}

@test "accent drives cursor, selection and link colors" {
  export_to "$BATS_TEST_TMPDIR/blue.json" --accent blue
  export_to "$BATS_TEST_TMPDIR/pink.json" --accent pink
  run jq -n -e --slurpfile a "$BATS_TEST_TMPDIR/blue.json" --slurpfile b "$BATS_TEST_TMPDIR/pink.json" '
    ["Cursor Color (Dark)", "Selection Color (Light)", "Link Color (Dark)"]
    | all(. as $k | $a[0].Profiles[0][$k] != $b[0].Profiles[0][$k])'
  assert_success_
  run jq -n -e --slurpfile a "$BATS_TEST_TMPDIR/blue.json" --slurpfile b "$BATS_TEST_TMPDIR/pink.json" '
    $a[0].Profiles[0]."Ansi 1 Color (Dark)" == $b[0].Profiles[0]."Ansi 1 Color (Dark)"'
  assert_success_
}
