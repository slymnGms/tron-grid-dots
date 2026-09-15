#!/usr/bin/env bash
# Dispatcher for the rice: hud rotate display update skin quote power scratch lowpower
set -u

REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/tron"
mkdir -p "$STATE"

usage() {
    cat <<'EOF'
usage: tron <command> [args]

  hud              toggle the HUD dashboard
  rotate [...]     screen orientation (see tron-rotate)
  display [...]    second-screen policy (see tron-display)
  update           git pull + re-link + re-theme
  skin [name]      idle overlay skin (list | next | tron|minimal|text|slides)
  quote            one Grid line
  power [action]   END OF LINE menu (or logout|reboot|poweroff|standby)
  scratch          show/hide the scratchpad terminal
  binds            keybind cheatsheet (rofi)
  lowpower [on|off|toggle]  kill picom + eww daemon (~80 MB back)
  help             this text
EOF
}

lowpower_on() {
    mkdir -p "$STATE"
    printf '1\n' >"$STATE/lowpower"
    pkill -x picom 2>/dev/null || true
    if command -v eww >/dev/null 2>&1; then
        eww close-all >/dev/null 2>&1 || true
        eww kill >/dev/null 2>&1 || true
    fi
    command -v notify-send >/dev/null && notify-send "POWER SAVE" "COMPOSITOR OFF — HUD starts on Super+D"
}

lowpower_off() {
    rm -f "$STATE/lowpower"
    # shellcheck source=../theme/palette.sh
    . "$REPO/theme/palette.sh"
    if ! pgrep -x picom >/dev/null 2>&1; then
        if [ -n "${TRON_FORCE_PICOM:-}" ] || ! systemd-detect-virt --vm --quiet 2>/dev/null; then
            read -r SR SG SB <<< "$(hex_to_rgb_frac "$TRON_ACCENT")"
            picom --config "$HOME/.config/picom/picom.conf" \
                  --shadow-red "$SR" --shadow-green "$SG" --shadow-blue "$SB" &
        fi
    fi
    command -v eww >/dev/null && { eww ping >/dev/null 2>&1 || eww daemon >/dev/null 2>&1 & }
    command -v notify-send >/dev/null && notify-send "POWER SAVE" "FULL GRID"
}

lowpower() {
    local now=off
    [ -f "$STATE/lowpower" ] && now=on
    case "${1:-toggle}" in
        on|1) lowpower_on ;;
        off|0) lowpower_off ;;
        toggle)
            if [ "$now" = on ]; then lowpower_off; else lowpower_on; fi
            ;;
        status) printf '%s\n' "$now" ;;
        *) printf 'usage: tron lowpower [on|off|toggle|status]\n' >&2; return 1 ;;
    esac
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    hud)        exec "$REPO/config/eww/scripts/hud-toggle.sh" ;;
    rotate)     exec "$REPO/scripts/rotate.sh" "$@" ;;
    display)    exec "$REPO/scripts/display.sh" "$@" ;;
    update)     exec "$REPO/scripts/update.sh" ;;
    skin)       exec "$REPO/scripts/skin-render.sh" "$@" ;;
    quote)      exec "$REPO/scripts/quote.sh" ;;
    power)      exec "$REPO/scripts/power.sh" "$@" ;;
    scratch)    exec "$REPO/scripts/scratch.sh" ;;
    binds|keys|help-keys) exec "$REPO/scripts/help.sh" ;;
    lowpower)   lowpower "${1:-toggle}" ;;
    help|-h|--help) usage ;;
    *) printf 'tron: unknown command: %s\n' "$cmd" >&2; usage >&2; exit 1 ;;
esac
