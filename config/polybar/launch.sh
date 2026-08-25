#!/usr/bin/env bash
# Restart-safe polybar launcher (called from bspwmrc / openbox autostart).
pkill -x polybar
# wait for the old instance to die (max ~2s)
for _ in $(seq 1 20); do pgrep -x polybar >/dev/null || break; sleep 0.1; done
polybar -q tron -c "$HOME/.config/polybar/config.ini" &
