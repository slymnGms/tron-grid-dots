#!/usr/bin/env bash
# System info for the HUD "IDENTITY DISC" card. One JSON line.

user="${USER:-program}"
host="$(hostname 2>/dev/null || echo grid)"
wm="${XDG_CURRENT_DESKTOP:-$(wmctrl -m 2>/dev/null | awk '/Name:/{print $2}')}"
wm="${wm:-bspwm}"
up="$(uptime -p 2>/dev/null | sed 's/^up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/')"
distro="$(. /etc/os-release 2>/dev/null && echo "$NAME $VERSION_ID")"

bat="--"
for b in /sys/class/power_supply/BAT*/capacity; do
    [ -r "$b" ] && bat="$(cat "$b")%" && break
done
for s in /sys/class/power_supply/*/status; do
    [ -r "$s" ] && [ "$(cat "$s")" = "Charging" ] && bat="$bat ⚡" && break
done

printf '{"user":"%s","host":"%s","wm":"%s","uptime":"%s","battery":"%s","distro":"%s"}\n' \
    "$user" "$host" "$wm" "${up:---}" "$bat" "${distro:-Lubuntu}"
