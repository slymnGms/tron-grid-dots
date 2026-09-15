#!/usr/bin/env bash
# Manual idle: close the HUD if it is open, then map the overlay.
set -u
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
command -v eww >/dev/null 2>&1 || exit 0
eww ping >/dev/null 2>&1 || eww daemon

if [ "$(eww get hud-visible 2>/dev/null)" = "true" ]; then
    eww update hud-visible=false
    eww close hud 2>/dev/null || true
fi
exec "$DIR/mirror-toggle.sh" show
