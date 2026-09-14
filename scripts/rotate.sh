#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 screen orientation (bound to Super+O, linked as
# tron-rotate). The panel is physically 90° off: at xrandr "normal" the top
# bar sits on the left physical edge. Landscape home is --rotate right.
# Display only for the panel; touchscreen is mapped to that output so
# fingers follow a 90° CW rotate. Touchpad is left on identity.
#
#   tron-rotate                  toggle right (landscape) <-> normal (portrait)
#   tron-rotate right            set landscape home
#   tron-rotate --ensure         set right only if not already (login),
#                                then apply display policy (internal primary,
#                                second screen mirror or off — never extend)
#   tron-rotate --map-inputs     remap touchscreen to the panel (not touchpad)
#   -q / --quiet                 no notification (session autostart)
# ============================================================================
set -u

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

display_bin() {
    # Prefer the sibling script even when git did not mark it +x (Windows
    # checkouts). Invoked with `bash` so execute-bit is not required.
    if [ -f "$HERE/display.sh" ]; then
        printf '%s\n' "$HERE/display.sh"
    elif [ -f /usr/local/bin/tron-display ]; then
        printf '%s\n' /usr/local/bin/tron-display
    elif command -v tron-display >/dev/null; then
        command -v tron-display
    fi
}

run_display() {
    local script
    script="$(display_bin)"
    [ -n "$script" ] || return 0
    bash "$script" "$@"
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
        --map-inputs|map-inputs) MAP_ONLY=1 ;;
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
    OUTPUT="$(run_display internal)" || OUTPUT=""
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

CURRENT="$(xrandr --query --verbose | awk -v target="$OUTPUT" '
    $1 == target {
        nw = split($0, w, /[ \t]+/)
        for (k = 1; k <= nw; k++) {
            if (w[k] == "normal" || w[k] == "left" || w[k] == "right" || w[k] == "inverted") {
                print w[k]
                exit
            }
        }
    }')"

# Display rotate is xrandr. Touchscreen/pen follow the panel via
# `xinput map-to-output` (so a 90° CW display does not swap finger axes).
# Touchpads/mice stay on the identity matrix — they are pointer devices,
# not mapped to the panel, and an earlier grep on "touch" broke the mousepad.
reset_touchpads() {
    command -v xinput >/dev/null || return 0
    xinput list --name-only | grep -iE 'touchpad|trackpoint|trackball' |
    while IFS= read -r dev; do
        [ -n "$dev" ] || continue
        xinput set-prop "$dev" 'Coordinate Transformation Matrix' \
            1 0 0 0 1 0 0 0 1 2>/dev/null
    done
}

map_touchscreens() {
    command -v xinput >/dev/null || return 0
    [ -n "$OUTPUT" ] || return 0
    local matrix
    case "${1:-$CURRENT}" in
        left)     matrix="0 -1 1 1 0 0 0 0 1" ;;
        right)    matrix="0 1 0 -1 0 1 0 0 1" ;;
        inverted) matrix="-1 0 1 0 -1 1 0 0 1" ;;
        *)        matrix="1 0 0 0 1 0 0 0 1" ;;
    esac
    xinput list --name-only |
    while IFS= read -r dev; do
        [ -n "$dev" ] || continue
        printf '%s\n' "$dev" | grep -qiE 'touchpad|trackpoint|trackball|mouse|keyboard' && continue
        if ! printf '%s\n' "$dev" | grep -qiE 'touchscreen|digitizer|goodix|silead|wacom|stylus|pen|finger'; then
            xinput list-props "$dev" 2>/dev/null | grep -q 'Abs MT Position' || continue
        fi
        # Explicit CTM for the current xrandr rotate. map-to-output is not
        # used: some builds ignore output rotation and would leave axes swapped.
        # shellcheck disable=SC2086
        xinput set-prop "$dev" 'Coordinate Transformation Matrix' $matrix 2>/dev/null
    done
}

map_inputs() {
    reset_touchpads
    map_touchscreens "${1:-}"
}

apply() {
    local next="$1"
    xrandr --output "$OUTPUT" --primary --rotate "$next" || { err "xrandr rotate failed"; exit 1; }
    map_inputs "$next"
    [ -n "$DISP" ] && run_display --quiet ensure || true
    notify "Display: $next"
}

if [ -n "${MAP_ONLY:-}" ]; then
    map_inputs
    exit 0
fi

apply_policy() {
    map_inputs "$CURRENT"
    [ -n "$DISP" ] && run_display --quiet ensure || true
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
