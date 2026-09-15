#!/usr/bin/env bash
# One reused kitty scratchpad (Super+grave). Avoids spawning a new ~90 MB window.
set -u

CLASS="tron-scratch"

wid=""
while read -r id _rest; do
    case "$_rest" in
        *"${CLASS}"*) wid="$id"; break ;;
    esac
done < <(wmctrl -lx 2>/dev/null)

spawn() {
    kitty --class "$CLASS" --title SCRATCH \
        -o remember_window_size=no \
        -o initial_window_width=900 \
        -o initial_window_height=500 \
        -o background_opacity=0.95 &
}

is_viewable() {
    xwininfo -id "$1" 2>/dev/null | grep -q 'Map State: IsViewable'
}

hide_win() {
    local id="$1"
    if command -v bspc >/dev/null 2>&1 && bspc query -N >/dev/null 2>&1; then
        bspc node "$id" -g hidden=on 2>/dev/null && return 0
    fi
    wmctrl -i -r "$id" -b add,hidden 2>/dev/null || true
    command -v xdotool >/dev/null 2>&1 && xdotool windowminimize "$id" 2>/dev/null || true
}

show_win() {
    local id="$1"
    if command -v bspc >/dev/null 2>&1 && bspc query -N >/dev/null 2>&1; then
        bspc node "$id" -g hidden=off -d focused -f 2>/dev/null && return 0
    fi
    wmctrl -i -r "$id" -b remove,hidden 2>/dev/null || true
    wmctrl -i -a "$id" 2>/dev/null || true
}

if [ -z "$wid" ]; then
    spawn
    exit 0
fi

if is_viewable "$wid"; then
    focused=""
    if command -v bspc >/dev/null 2>&1; then
        focused="$(bspc query -N -n focused 2>/dev/null || true)"
    fi
    # hide when already on screen; raise if it is viewable but not focused
    if [ -n "$focused" ] && [ "${focused,,}" != "${wid,,}" ]; then
        # ids may differ only by padding (0x00ab vs 0xab)
        fdec=$((focused))
        wdec=$((wid))
        if [ "$fdec" -eq "$wdec" ]; then
            hide_win "$wid"
        else
            show_win "$wid"
        fi
    else
        hide_win "$wid"
    fi
else
    show_win "$wid"
fi
