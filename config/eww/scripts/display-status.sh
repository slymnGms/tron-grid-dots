#!/bin/sh
# eww defpoll helper — second-screen status: none | off | mirror
if command -v tron-display >/dev/null; then
    exec tron-display status
fi
HERE="$(dirname "$(readlink -f "$0")")"
REPO="$(dirname "$(dirname "$(dirname "$HERE")")")"
if [ -x "$REPO/scripts/display.sh" ]; then
    exec "$REPO/scripts/display.sh" status
fi
echo none
