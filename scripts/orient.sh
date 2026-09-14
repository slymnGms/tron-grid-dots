#!/bin/sh
# ============================================================================
# tron-grid-dots — D330 landscape home (90° clockwise).
# Used at boot (systemd/udev) and as a no-op-if-done helper for fbcon.
# X display ensure is tron-rotate --ensure (needs a display; inputs untouched).
#
#   tron-orient           ensure fbcon now; if DISPLAY is set, ensure xrandr
#   tron-orient --boot    wait for fbcon, then ensure (systemd oneshot)
#   tron-orient --fbcon   ensure fbcon only, no wait (udev / greetd)
# ============================================================================

HOME_FBCON=1

fbcon_read() {
    if [ -r /sys/class/graphics/fbcon/rotate_all ]; then
        tr -dc '0-9' </sys/class/graphics/fbcon/rotate_all
    elif [ -r /sys/class/graphics/fbcon/rotate ]; then
        tr -dc '0-9' </sys/class/graphics/fbcon/rotate
    fi
}

fbcon_write() {
    if [ -w /sys/class/graphics/fbcon/rotate_all ]; then
        printf '%s\n' "$HOME_FBCON" >/sys/class/graphics/fbcon/rotate_all 2>/dev/null && return 0
    fi
    if [ -w /sys/class/graphics/fbcon/rotate ]; then
        printf '%s\n' "$HOME_FBCON" >/sys/class/graphics/fbcon/rotate 2>/dev/null && return 0
    fi
    return 1
}

ensure_fbcon() {
    cur="$(fbcon_read)"
    [ "$cur" = "$HOME_FBCON" ] && return 0
    fbcon_write
}

wait_fbcon() {
    n=0
    while [ "$n" -lt 20 ]; do
        if [ -e /sys/class/graphics/fbcon/rotate_all ] || [ -e /sys/class/graphics/fbcon/rotate ]; then
            return 0
        fi
        n=$((n + 1))
        sleep 0.5
    done
    return 1
}

ensure_xrandr() {
    [ -n "${DISPLAY:-}" ] || return 0
    if [ -x /usr/local/bin/tron-rotate ]; then
        /usr/local/bin/tron-rotate --quiet --ensure || true
        return 0
    fi
    command -v xrandr >/dev/null || return 0
    xrandr --query >/dev/null 2>&1 || return 0
    out=$(xrandr --query | awk '
        $2 == "connected" {
            if ($1 ~ /^(eDP|DSI|LVDS)/) { print $1; found=1; exit }
            if (!first) first=$1
        }
        END { if (!found && first) print first }
    ')
    [ -n "$out" ] || return 0
    xrandr --output "$out" --primary >/dev/null 2>&1 || true
    cur=$(xrandr --query --verbose | awk -v target="$out" '
        $1 == target {
            nw = split($0, w, /[ \t]+/)
            for (k = 1; k <= nw; k++) {
                if (w[k] == "normal" || w[k] == "left" || w[k] == "right" || w[k] == "inverted") {
                    print w[k]
                    exit
                }
            }
        }')
    [ "$cur" = "right" ] && return 0
    xrandr --output "$out" --primary --rotate right || true
}

mode="${1:-}"
case "$mode" in
    --boot)
        wait_fbcon || exit 0
        ensure_fbcon || true
        ;;
    --fbcon)
        ensure_fbcon || true
        ;;
    ""|--ensure)
        ensure_fbcon || true
        ensure_xrandr
        ;;
    -h|--help)
        printf 'usage: tron-orient [--boot|--fbcon|--ensure]\n'
        ;;
    *)
        printf 'tron-orient: unknown argument: %s\n' "$mode" >&2
        exit 1
        ;;
esac
exit 0
