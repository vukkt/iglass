#!/usr/bin/env python3
"""Check iglass's Warp files the way Warp reads them (used by CI with the real Warp).

    python3 tools/check_warp.py SCHEMA SETTINGS_TOML THEME_YAML...

SCHEMA is the settings_schema.json a Warp release ships. The settings file must parse as TOML
and match that schema, so a setting Warp renamed or a value it no longer accepts fails here.
Each theme must be YAML with the keys Warp's custom themes use and #rrggbb colors.
Needs the jsonschema and PyYAML packages (and tomli on Python before 3.11).
"""

import json
import re
import sys

try:
    import tomllib
except ModuleNotFoundError:  # Python < 3.11
    import tomli as tomllib

import jsonschema
import yaml

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def check_settings(schema_path, settings_path):
    with open(schema_path, encoding="utf-8") as f:
        schema = json.load(f)
    with open(settings_path, "rb") as f:
        settings = tomllib.load(f)
    validator = jsonschema.Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(settings), key=lambda e: list(e.path))
    for e in errors:
        print(f"{settings_path}: {'.'.join(map(str, e.path)) or '(top)'}: {e.message}")
    themes = settings.get("appearance", {}).get("themes", {})
    if "custom" not in themes.get("theme", {}):
        print(f"{settings_path}: appearance.themes.theme is not a custom theme")
        return 1
    return len(errors)


def check_theme(path):
    with open(path, encoding="utf-8") as f:
        theme = yaml.safe_load(f)
    problems = []
    for key in ["name", "accent", "cursor", "background", "foreground", "details", "terminal_colors"]:
        if key not in theme:
            problems.append(f"missing {key}")
    if theme.get("details") not in ("darker", "lighter"):
        problems.append("details must be darker or lighter")
    colors = [theme.get(k) for k in ("accent", "cursor", "background", "foreground")]
    for group in ("normal", "bright"):
        values = (theme.get("terminal_colors") or {}).get(group) or {}
        if sorted(values) != sorted(ANSI):
            problems.append(f"terminal_colors.{group} needs exactly {', '.join(ANSI)}")
        colors += list(values.values())
    problems += [f"not a #rrggbb color: {c!r}" for c in colors if not (isinstance(c, str) and HEX.match(c))]
    for p in problems:
        print(f"{path}: {p}")
    return len(problems)


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip())
        return 2
    count = check_settings(argv[1], argv[2]) + sum(check_theme(p) for p in argv[3:])
    if count:
        print(f"{count} problem(s)")
        return 1
    print(f"Warp accepts {argv[2]} and {len(argv) - 3} theme(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
