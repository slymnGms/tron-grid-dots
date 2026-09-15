#!/usr/bin/env bash
# Print one random line from theme/quotes.txt (idle widget, fish greeting, tron quote).
set -u

REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
FILE="$REPO/theme/quotes.txt"

if [ ! -r "$FILE" ]; then
    printf 'Greetings, program.\n'
    exit 0
fi

# awk picks a random non-empty, non-comment line without loading extra tools
awk '
    NF && $1 !~ /^#/ { lines[++n] = $0 }
    END {
        if (n < 1) { print "Greetings, program."; exit }
        srand()
        print lines[int(rand() * n) + 1]
    }
' "$FILE"
