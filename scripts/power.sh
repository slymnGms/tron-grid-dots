#!/usr/bin/env bash
# Themed power menu. No args -> rofi. HUD passes logout|reboot|poweroff|standby.
set -u

REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
TOGGLE="${XDG_CONFIG_HOME:-$HOME/.config}/eww/scripts/mirror-toggle.sh"
[ -x "$TOGGLE" ] || TOGGLE="$REPO/config/eww/scripts/mirror-toggle.sh"

logout_cmd() {
    if command -v bspc >/dev/null 2>&1 && bspc query -B >/dev/null 2>&1; then
        bspc quit
    else
        openbox --exit 2>/dev/null || loginctl terminate-session "$XDG_SESSION_ID"
    fi
}

run() {
    case "$1" in
        logout|LOGOUT) logout_cmd ;;
        reboot|"REBOOT THE GRID"|REBOOT) systemctl reboot ;;
        poweroff|DERESOLUTION|SHUTDOWN) systemctl poweroff ;;
        standby|"STAND BY"|mirror)
            if [ -x "$TOGGLE" ]; then
                "$TOGGLE" show
            fi
            ;;
        *) return 1 ;;
    esac
}

if [ "${1:-}" != "" ]; then
    run "$1"
    exit $?
fi

choice="$(printf 'LOGOUT\nREBOOT THE GRID\nDERESOLUTION\nSTAND BY\n' \
    | rofi -dmenu -i -p 'END OF LINE' -theme tron)"
[ -n "${choice:-}" ] || exit 0
run "$choice"
