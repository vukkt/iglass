# Development tasks. Requires: python3 (palette build), shellcheck and bats-core (lint/tests).

SHELL_FILES := bin/iglass lib/*.sh install.sh tools/*.sh tests/*.bash tests/*.bats

.PHONY: all palettes themes lint test check-generated check

all: palettes themes

## Rebuild data/palette.json, docs/contrast-report.md and themes/*.itermcolors
palettes:
	python3 tools/build_palettes.py

## Rebuild the prebuilt files for people who don't use the CLI: themes/iglass.json (iTerm2)
## and themes/ghostty/ (Ghostty, real Liquid Glass for macOS 26+)
themes:
	bin/iglass export > themes/iglass.json
	rm -rf themes/ghostty
	NO_COLOR=1 bin/iglass export --terminal ghostty --glass native --dir themes/ghostty >/dev/null

lint:
	shellcheck $(SHELL_FILES)

test:
	python3 -m unittest discover -s tests -p 'test_*.py'
	bats tests/

## Fail when generated files don't match their sources
check-generated:
	python3 tools/build_palettes.py --check
	bin/iglass export | cmp -s - themes/iglass.json || \
		(echo "themes/iglass.json is out of date: run make themes" >&2; exit 1)
	rm -rf .check-ghostty && NO_COLOR=1 bin/iglass export --terminal ghostty --glass native --dir .check-ghostty >/dev/null
	diff -r themes/ghostty .check-ghostty >/dev/null || \
		(rm -rf .check-ghostty; echo "themes/ghostty is out of date: run make themes" >&2; exit 1)
	rm -rf .check-ghostty

check: lint check-generated test
