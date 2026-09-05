#!/usr/bin/env bash
# check-ascii-output.sh - fail if an operator-facing string in src/ carries a non-ASCII character.
#
#   scripts/check-ascii-output.sh
#
# Anything that reaches a terminal comes back as <E2><80><94> in `journalctl`, whose pager runs
# under a C locale on a stock Debian box - so an em dash or a U+2192 arrow in a message is noise
# in the one place someone reads it. These are libraries rather than daemons, so the surface that
# matters here is exception messages: they are what a consuming app logs.
#
# What is checked, in src/ only (comments and docs are free to use whatever notation they like):
#   - every double-quoted string literal on a line that throws or builds an exception
#   - Console output, for anything that grows a CLI later
#
# This is a cheap line-based tripwire, not a lexer. If it ever needs to be exact, parse with
# Roslyn rather than widening the grep until it false-positives.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

patterns='throw new |Exception\(|Console\.(Write|WriteLine|Error\.|Out\.)'

hits="$(grep -rnE --include='*.cs' "$patterns" src/ | grep -P '"[^"]*[^\x00-\x7F][^"]*"' || true)"

if [ -n "$hits" ]; then
    echo "::error::non-ASCII characters in operator-facing output (they render as <E2><80><94> in journalctl)"
    echo "$hits"
    echo
    echo "Use plain ASCII: '->' not an arrow, '-' or ';' not an em dash. Comments may keep theirs."
    exit 1
fi

echo "ok: every exception message and Console string in src/ is plain ASCII"
