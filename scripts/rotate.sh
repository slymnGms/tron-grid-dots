#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 tablet-mode rotation toggle (bound to Super+O,
# linked into ~/.local/bin as tron-rotate).
#
# Cycles normal -> left (portrait) -> normal, rotating the panel with xrandr
# and remapping every touch device with xinput so finger input follows.
# ============================================================================
set -u

err() { printf 'rotate: %s\n' "$*" >&2; command -v notify-send >/dev/null && notify-send "ROTATE" "$*"; }

command -v xrandr >/dev/null || { err "xrandr not found"; exit 1; }

# internal panel = first connected output (D330 has one; HDMI would be second)
OUTPUT="$(xrandr --query | awk '/ connected/{print $1; exit}')"
[ -n "$OUTPUT" ] || { err "no connected output found"; exit 1; }

CURRENT="$(xrandr --query --verbose | awk -v o="$OUTPUT" '$1==o {print $5; exit}')"

case "$CURRENT" in
    normal) NEXT="left";  MATRIX="0 -1 1 1 0 0 0 0 1" ;;
    *)      NEXT="normal"; MATRIX="1 0 0 0 1 0 0 0 1" ;;
esac

xrandr --output "$OUTPUT" --rotate "$NEXT" || { err "xrandr rotate failed"; exit 1; }

# remap touchscreen + pen so touches land where they look
if command -v xinput >/dev/null; then
    xinput list --name-only | grep -iE 'touch|finger|pen|stylus|goodix|silead|wacom' |
    while IFS= read -r dev; do
        # shellcheck disable=SC2086
        xinput set-prop "$dev" 'Coordinate Transformation Matrix' $MATRIX 2>/dev/null
    done
fi

command -v notify-send >/dev/null && notify-send "ROTATE" "Display: $NEXT"
exit 0
