#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 display policy (linked as tron-display).
#
# The built-in panel is always the primary (device) display. A real second
# monitor mirrors it — never extends — because USB-C PD chargers often
# advertise a phantom DP output that would otherwise become a second X
# screen and break bspwm/polybar geometry.
#
#   tron-display internal   print the built-in output name
#   tron-display ensure     primary + off phantoms + mirror if enabled
#   tron-display toggle     HUD: enable/disable the second screen
#   tron-display on|off     force preference
#   tron-display status     none | off | mirror   (for eww)
#   tron-display watch      re-apply on hotplug (USB-C plug, HDMI, …)
# ============================================================================
set -u

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tron"
STATE="$STATE_DIR/external"
QUIET="${QUIET:-}"

err() { printf 'display: %s\n' "$*" >&2; }
notify() {
    [ -n "$QUIET" ] && return 0
    command -v notify-send >/dev/null && notify-send "DISPLAY" "$*"
    return 0
}

for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=1 ;;
    esac
done

command -v xrandr >/dev/null || { err "xrandr not found"; exit 1; }

# Built-in panel: eDP / DSI / LVDS. Never the first "connected" output —
# a USB-C charger can enumerate DP-1 first and steal primary.
internal_output() {
    local n=0 name=""
    while [ "$n" -lt 10 ]; do
        name="$(xrandr --query 2>/dev/null | awk '
            $2 == "connected" {
                if ($1 ~ /^(eDP|DSI|LVDS)/) { print $1; found=1; exit }
                if (!first) first=$1
            }
            END { if (!found && first) print first }
        ')"
        [ -n "$name" ] && { printf '%s\n' "$name"; return 0; }
        n=$((n + 1))
        sleep 0.1
    done
    return 1
}

externals_connected() {
    local panel="$1"
    xrandr --query | awk -v panel="$panel" '$2 == "connected" && $1 != panel { print $1 }'
}

# Real sink: DRM EDID is at least one block. USB-C PD often shows
# "connected" with a 0-byte edid and no usable modes.
has_edid() {
    local out="$1" d bytes=0
    shopt -s nullglob
    for d in /sys/class/drm/card*-"$out"; do
        [ -f "$d/edid" ] || continue
        bytes="$(wc -c < "$d/edid" 2>/dev/null | tr -dc '0-9')"
        [ "${bytes:-0}" -ge 128 ] && { shopt -u nullglob; return 0; }
    done
    shopt -u nullglob
    xrandr --query | awk -v o="$out" '
        $1 == o { p=1; next }
        p && /^[A-Za-z]/ { exit }
        p && $1 ~ /^[0-9]+x[0-9]+/ { found=1; exit }
        END { exit found ? 0 : 1 }
    '
}

pref_get() {
    if [ -f "$STATE" ]; then
        cat "$STATE"
    else
        printf 'on\n'
    fi
}

pref_set() {
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$1" >"$STATE"
}

# Is this output currently driving pixels? (clone/on vs listed-but-off)
output_active() {
    local out="$1"
    xrandr --query | awk -v o="$out" '
        $1 == o && $2 == "connected" && $3 ~ /^[0-9]+x[0-9]+/ { found=1 }
        END { exit found ? 0 : 1 }
    '
}

status_word() {
    local panel ext real=0 active=0
    panel="$(internal_output)" || { printf 'none\n'; return 0; }
    while IFS= read -r ext; do
        [ -n "$ext" ] || continue
        has_edid "$ext" || continue
        real=1
        output_active "$ext" && active=1
    done <<EOF
$(externals_connected "$panel")
EOF
    if [ "$real" -eq 0 ]; then
        printf 'none\n'
    elif [ "$active" -eq 1 ]; then
        printf 'mirror\n'
    else
        printf 'off\n'
    fi
}

apply_layout() {
    local panel ext pref
    panel="$(internal_output)" || { err "no internal panel"; return 1; }

    # Device display owns the origin and primary flag — never a DP from USB-C.
    xrandr --output "$panel" --primary || true

    pref="$(pref_get)"
    [ "$pref" = "off" ] || pref="on"

    while IFS= read -r ext; do
        [ -n "$ext" ] || continue
        if ! has_edid "$ext"; then
            xrandr --output "$ext" --off 2>/dev/null || true
            continue
        fi
        if [ "$pref" = "off" ]; then
            xrandr --output "$ext" --off 2>/dev/null || true
            continue
        fi
        # Mirror the panel. Never --left-of/--right-of (that is what broke
        # geometry when a charger advertised a fake second screen).
        xrandr --output "$ext" --auto --rotate normal --same-as "$panel" 2>/dev/null ||
            xrandr --output "$ext" --off 2>/dev/null || true
    done <<EOF
$(externals_connected "$panel")
EOF

    # USB-C expand can leave a ghost bspwm monitor with broken geometry.
    if command -v bspc >/dev/null && pgrep -x bspwm >/dev/null; then
        extras=0
        while IFS= read -r m; do
            [ -n "$m" ] && [ "$m" != "$panel" ] || continue
            extras=1
            bspc monitor "$m" -r 2>/dev/null || true
        done <<EOF
$(bspc query -M --names 2>/dev/null)
EOF
        if [ "$extras" -eq 1 ]; then
            bspc monitor "$panel" -d 1 2 3 4 5 6 2>/dev/null || true
        fi
    fi

    [ -f "$HERE/rotate.sh" ] && bash "$HERE/rotate.sh" --quiet --map-inputs || true
}

cmd="${1:-ensure}"
[ "$cmd" = "-q" ] || [ "$cmd" = "--quiet" ] && cmd="${2:-ensure}"

case "$cmd" in
    internal)
        internal_output
        ;;
    ensure|apply)
        apply_layout
        ;;
    status)
        status_word
        ;;
    on)
        pref_set on
        apply_layout
        notify "EXTERNAL: MIRROR"
        ;;
    off)
        pref_set off
        apply_layout
        notify "EXTERNAL: OFF"
        ;;
    toggle)
        if [ "$(pref_get)" = "off" ]; then
            pref_set on
            apply_layout
            case "$(status_word)" in
                mirror) notify "EXTERNAL: MIRROR" ;;
                *)      notify "EXTERNAL: no display (USB-C power is ignored)" ;;
            esac
        else
            pref_set off
            apply_layout
            notify "EXTERNAL: OFF"
        fi
        if command -v eww >/dev/null && eww ping >/dev/null 2>&1; then
            eww update ext-screen="$(status_word)" 2>/dev/null || true
        fi
        ;;
    watch)
        # Re-apply when a cable/charger is plugged so X cannot expand the
        # desktop onto a phantom DP output.
        last=0
        handle() {
            now="$(date +%s)"
            [ $((now - last)) -lt 1 ] && return 0
            last=$now
            apply_layout || true
        }
        handle
        if command -v bspc >/dev/null && pgrep -x bspwm >/dev/null; then
            bspc subscribe monitor | while IFS= read -r _; do handle; done
        else
            prev=""
            while sleep 2; do
                cur="$(xrandr --query | awk '$2=="connected"{print $1}')"
                [ "$cur" = "$prev" ] && continue
                prev="$cur"
                handle
            done
        fi
        ;;
    -h|--help)
        printf 'usage: tron-display [-q] [internal|ensure|toggle|on|off|status|watch]\n'
        ;;
    *)
        err "usage: tron-display [-q] [internal|ensure|toggle|on|off|status|watch]"
        exit 1
        ;;
esac
exit 0
