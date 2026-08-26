#!/usr/bin/env bash
# Toggle the HUD with the slide animation (bound to Super+D and the bar button).
# State is read from the hud-visible variable — parsing `eww active-windows`
# output proved format-fragile and could leave an empty frame stuck open.
command -v eww >/dev/null 2>&1 || { notify-send "eww" "eww is not installed"; exit 1; }

# start the daemon on demand if bspwmrc didn't
eww ping >/dev/null 2>&1 || eww daemon

if [ "$(eww get hud-visible 2>/dev/null)" = "true" ]; then
    eww update hud-visible=false
    sleep 0.3   # let the slide-out play before the window unmaps
    eww close hud 2>/dev/null
else
    eww open hud 2>/dev/null
    eww update hud-visible=true
fi
