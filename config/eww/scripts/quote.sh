#!/usr/bin/env bash
# Quote helper from the eww config dir (cwd for defpoll).
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
REPO="$(dirname "$(dirname "$(dirname "$HERE")")")"
exec "$REPO/scripts/quote.sh"
