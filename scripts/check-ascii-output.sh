#!/usr/bin/env bash
# check-ascii-output.sh - two tripwires:
#
#   1. fail if an operator-facing string in src/ carries a non-ASCII character.
#   2. fail if any git-tracked file other than LICENSE contains an em dash (U+2014) or
#      an en dash (U+2013).
#
#   scripts/check-ascii-output.sh
#
# Anything that reaches a terminal comes back as <E2><80><94> in `journalctl`, whose pager runs
# under a C locale on a stock Debian box - so an em dash or a U+2192 arrow in a message is noise
# in the one place someone reads it. These are libraries rather than daemons, so the surface that
# matters here is exception messages: they are what a consuming app logs.
#
# Check 1, in src/ only (comments and docs are free to use whatever notation they like):
#   - every double-quoted string literal on a line that throws or builds an exception
#   - Console output, for anything that grows a CLI later
#
# Check 2, across the whole tree (comments, docs, everything except LICENSE, which is a
# verbatim licence text and not ours to edit): no em dash or en dash anywhere. This repo's
# style is a hyphen, a comma or a semicolon instead - see the project CLAUDE.md.
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

dash_hits=""
while IFS= read -r -d '' file; do
    if [ "$file" = "LICENSE" ]; then
        continue
    fi
    if [ -f "$file" ] && file_hits="$(grep -n $'\xE2\x80\x94\|\xE2\x80\x93' -- "$file" 2>/dev/null || true)" && [ -n "$file_hits" ]; then
        dash_hits+="$file:"$'\n'"$file_hits"$'\n'
    fi
done < <(git ls-files -z)

if [ -n "$dash_hits" ]; then
    echo "::error::em dash (U+2014) or en dash (U+2013) found in a tracked file"
    echo "$dash_hits"
    echo
    echo "Use a hyphen, comma or semicolon instead."
    exit 1
fi

echo "ok: no em dash or en dash in any tracked file other than LICENSE"
