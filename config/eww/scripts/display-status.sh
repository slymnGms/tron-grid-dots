#!/bin/sh
# eww defpoll helper — second-screen status: none | off | mirror
HERE="$(dirname "$(readlink -f "$0")")"
REPO="$(dirname "$(dirname "$(dirname "$HERE")")")"
if [ -f "$REPO/scripts/display.sh" ]; then
    exec bash "$REPO/scripts/display.sh" status
fi
if command -v tron-display >/dev/null; then
    exec bash "$(command -v tron-display)" status
fi
echo none
