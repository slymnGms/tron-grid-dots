#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 screen orientation (bound to Super+O, linked as
# tron-rotate). The panel is physically 90° off: at xrandr "normal" the top
# bar sits on the left physical edge. Landscape home is --rotate right.
# Display only — touchpad/touchscreen/pen stay on the identity matrix.
#
#   tron-rotate                  toggle right (landscape) <-> normal (portrait)
#   tron-rotate right            set landscape home
#   tron-rotate --ensure         set right only if not already (login),
#                                then apply display policy (internal primary,
#                                second screen mirror or off — never extend)
#   tron-rotate normal|left|inverted
#   -q / --quiet                 no notification (session autostart)
# ============================================================================
set -u

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

display_bin() {
    if [ -x "$HERE/display.sh" ]; then
        printf '%s\n' "$HERE/display.sh"
    elif [ -x /usr/local/bin/tron-display ]; then
        printf '%s\n' /usr/local/bin/tron-display
    elif command -v tron-display >/dev/null; then
        command -v tron-display
    fi
}

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

# Built-in panel only. USB-C power can list DP-1 as connected first.
OUTPUT=""
DISP="$(display_bin)"
if [ -n "$DISP" ]; then
    OUTPUT="$("$DISP" internal)" || OUTPUT=""
fi
if [ -z "$OUTPUT" ]; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        OUTPUT="$(xrandr --query | awk '
            $2 == "connected" {
                if ($1 ~ /^(eDP|DSI|LVDS)/) { print $1; found=1; exit }
                if (!first) first=$1
            }
            END { if (!found && first) print first }
        ')"
        [ -n "$OUTPUT" ] && break
        sleep 0.1
    done
fi
[ -n "$OUTPUT" ] || { err "no connected output found"; exit 1; }

CURRENT="$(xrandr --query --verbose | awk -v o="$OUTPUT" '
    $1 == o {
        for (i = 1; i <= NF; i++)
            if ($i == "normal" || $i == "left" || $i == "right" || $i == "inverted") {
                print $i; exit
            }
    }')"

# Undo any Coordinate Transformation Matrix left from older tron-rotate
# (that grep matched the touchpad too). Display rotation is xrandr only.
reset_input_maps() {
    command -v xinput >/dev/null || return 0
    xinput list --name-only | grep -iE 'touch|finger|pen|stylus|goodix|silead|wacom' |
    while IFS= read -r dev; do
        xinput set-prop "$dev" 'Coordinate Transformation Matrix' \
            1 0 0 0 1 0 0 0 1 2>/dev/null
    done
}

apply() {
    local next="$1"
    xrandr --output "$OUTPUT" --primary --rotate "$next" || { err "xrandr rotate failed"; exit 1; }
    reset_input_maps
    [ -n "$DISP" ] && "$DISP" --quiet ensure || true
    notify "Display: $next"
}

reset_input_maps

apply_policy() {
    [ -n "$DISP" ] && "$DISP" --quiet ensure || true
}

if [ -n "$TARGET" ]; then
    # login/autostart: skip the xrandr call if the panel is already home
    if [ "$ENSURE" = 1 ] && [ "$CURRENT" = "$TARGET" ]; then
        apply_policy
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
