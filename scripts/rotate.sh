#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 screen orientation (bound to Super+O, linked as
# tron-rotate). The panel is physically 90° off: at xrandr "normal" the top
# bar sits on the left physical edge. Landscape home is --rotate right.
#
#   tron-rotate                  toggle right (landscape) <-> normal (portrait)
#   tron-rotate right            set landscape home
#   tron-rotate --ensure         set right only if not already (login)
#   tron-rotate normal|left|inverted
#   -q / --quiet                 no notification (session autostart)
# ============================================================================
set -u

err() { printf 'rotate: %s\n' "$*" >&2; command -v notify-send >/dev/null && notify-send "ROTATE" "$*"; }

notify() {
    [ -n "${QUIET:-}" ] && return 0
    command -v notify-send >/dev/null && notify-send "ROTATE" "$*"
    return 0
}

TARGET=""
ENSURE=0
QUIET="${QUIET:-}"
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=1 ;;
        --ensure|ensure) ENSURE=1; TARGET="${TARGET:-right}" ;;
        normal|left|right|inverted) TARGET="$arg" ;;
        -h|--help)
            printf 'usage: tron-rotate [-q] [--ensure] [normal|left|right|inverted]\n'
            exit 0
            ;;
        *) err "usage: tron-rotate [-q] [--ensure] [normal|left|right|inverted]"; exit 1 ;;
    esac
done

command -v xrandr >/dev/null || { err "xrandr not found"; exit 1; }

# internal panel = first connected output (D330 has one; HDMI would be second).
# Retry briefly: at login X may not have advertised the DSI/eDP output yet.
OUTPUT=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    OUTPUT="$(xrandr --query | awk '/ connected/{print $1; exit}')"
    [ -n "$OUTPUT" ] && break
    sleep 0.1
done
[ -n "$OUTPUT" ] || { err "no connected output found"; exit 1; }

CURRENT="$(xrandr --query --verbose | awk -v o="$OUTPUT" '
    $1 == o {
        for (i = 1; i <= NF; i++)
            if ($i == "normal" || $i == "left" || $i == "right" || $i == "inverted") {
                print $i; exit
            }
    }')"

matrix_for() {
    case "$1" in
        normal)   printf '1 0 0 0 1 0 0 0 1' ;;
        left)     printf '0 -1 1 1 0 0 0 0 1' ;;
        right)    printf '0 1 0 -1 0 1 0 0 1' ;;
        inverted) printf '-1 0 1 0 -1 1 0 0 1' ;;
        *) return 1 ;;
    esac
}

apply() {
    local next="$1" matrix
    matrix="$(matrix_for "$next")" || { err "unknown rotation: $next"; exit 1; }
    xrandr --output "$OUTPUT" --rotate "$next" || { err "xrandr rotate failed"; exit 1; }

    # remap touchscreen + pen so touches land where they look
    if command -v xinput >/dev/null; then
        xinput list --name-only | grep -iE 'touch|finger|pen|stylus|goodix|silead|wacom' |
        while IFS= read -r dev; do
            # shellcheck disable=SC2086
            xinput set-prop "$dev" 'Coordinate Transformation Matrix' $matrix 2>/dev/null
        done
    fi

    notify "Display: $next"
}

if [ -n "$TARGET" ]; then
    # login/autostart: skip the xrandr call if boot or Xsetup already rotated
    if [ "$ENSURE" = 1 ] && [ "$CURRENT" = "$TARGET" ]; then
        exit 0
    fi
    apply "$TARGET"
    exit 0
fi

# D330 home is right (landscape). Super+O flips to normal (portrait) and back.
case "$CURRENT" in
    right) apply normal ;;
    *)     apply right ;;
esac
exit 0
