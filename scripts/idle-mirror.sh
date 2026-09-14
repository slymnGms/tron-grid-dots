#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — idle "magic mirror" (clock / weather overlay).
#
# Why the stock screensaver could not be stopped: Lubuntu/LXQt (xscreensaver,
# light-locker, xfce4-screensaver, lxqt-powermanagement) blanks or locks the
# X server. On the D330 the rotated panel + grabbed pointer means tap/click
# never reaches a dismiss UI, so the black lock sticks. This rice disables
# those daemons and DPMS, then shows a tap-anywhere eww overlay instead.
# ============================================================================
set -u

IDLE_MS="${TRON_MIRROR_IDLE_MS:-300000}"   # 5 minutes
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tron"
FLAG="$STATE_DIR/mirror-open"
mkdir -p "$STATE_DIR"

EWW_SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/eww/scripts"
TOGGLE="$EWW_SCRIPTS/mirror-toggle.sh"

kill_stock() {
    # DPMS/blank is what turns the panel black with no way to wake it.
    command -v xset >/dev/null && xset s off s noblank -dpms 2>/dev/null || true
    command -v xscreensaver-command >/dev/null && xscreensaver-command -exit 2>/dev/null || true
    pkill -x xscreensaver 2>/dev/null || true
    pkill -x xfce4-screensaver 2>/dev/null || true
    pkill -x light-locker 2>/dev/null || true
    pkill -x gnome-screensaver 2>/dev/null || true
    pkill -x xss-lock 2>/dev/null || true
    pkill -x xautolock 2>/dev/null || true
}

inhibited() {
    # Don't overlay Kodi / emulation / a fullscreen window.
    pgrep -x kodi >/dev/null && return 0
    pgrep -x retroarch >/dev/null && return 0
    pgrep -x es-de >/dev/null && return 0
    if command -v bspc >/dev/null; then
        bspc query -N -n '.fullscreen.local' >/dev/null 2>&1 && return 0
    fi
    return 1
}

is_open() { [ -f "$FLAG" ] && [ "$(cat "$FLAG" 2>/dev/null)" = "1" ]; }

show() { [ -x "$TOGGLE" ] && "$TOGGLE" show; }
hide() { [ -x "$TOGGLE" ] && "$TOGGLE" hide; }

kill_stock
hide

tick=0
while true; do
    tick=$((tick + 1))
    # Power managers like to turn DPMS back on; re-assert often.
    [ $((tick % 15)) -eq 1 ] && kill_stock

    idle=0
    if command -v xprintidle >/dev/null; then
        idle="$(xprintidle 2>/dev/null || echo 0)"
    fi

    if is_open; then
        if [ "$idle" -lt 800 ]; then
            hide
        fi
    else
        if [ "$idle" -ge "$IDLE_MS" ] && ! inhibited; then
            show
        fi
    fi
    sleep 2
done
