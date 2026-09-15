#!/usr/bin/env bash
# Show / hide the MagicMirror-style idle overlay (tap anywhere to resume).
set -u
command -v eww >/dev/null 2>&1 || exit 0

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tron"
FLAG="$STATE_DIR/mirror-open"
mkdir -p "$STATE_DIR"

eww ping >/dev/null 2>&1 || eww daemon

cmd="${1:-toggle}"
is_on() { [ -f "$FLAG" ] && [ "$(cat "$FLAG" 2>/dev/null)" = "1" ]; }

show() {
    # skin yuck must exist before the window can map
    if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/eww/mirror.gen.yuck" ]; then
        command -v tron >/dev/null && tron skin >/dev/null 2>&1 || true
    fi
    eww open mirror 2>/dev/null || true
    printf '1\n' >"$FLAG"
}

hide() {
    eww close mirror 2>/dev/null || true
    printf '0\n' >"$FLAG"
}

case "$cmd" in
    show) show ;;
    hide) hide ;;
    toggle) if is_on; then hide; else show; fi ;;
    *) hide ;;
esac
