# Security

iglass edits files in your home folder (terminal themes and configs) and, only when you ask
with `--app-settings` or `--default`, iTerm2's preferences. It never needs root, and it backs
up what it changes before changing it.

## Reporting a vulnerability

Please report security problems privately, not in a public issue:
**[Report a vulnerability](https://github.com/vukkt/iglass/security/advisories/new)**
(GitHub's private reporting). Include the iglass version (`iglass --version`), your OS, and
steps to reproduce. You'll get a reply within a few days.

Examples of what counts: iglass writing outside the files it documents, losing or corrupting a
config it edits, or the installer fetching code from somewhere other than this repository.

## Supported versions

Fixes go into the latest release. Update with `brew upgrade iglass`, or rerun the install script.
