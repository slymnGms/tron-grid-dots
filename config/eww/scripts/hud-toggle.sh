#!/usr/bin/env bash
# Toggle the HUD with the slide animation (bound to Super+D and the bar button).
command -v eww >/dev/null 2>&1 || { notify-send "eww" "eww is not installed"; exit 1; }

# start the daemon on demand if bspwmrc didn't
eww ping >/dev/null 2>&1 || eww daemon

if eww active-windows 2>/dev/null | grep -q '^hud'; then
    eww update hud-visible=false
    sleep 0.3   # let the slide-out play before the window unmaps
    eww close hud
else
    eww open hud
    eww update hud-visible=true
fi
