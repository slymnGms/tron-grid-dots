#!/usr/bin/env bash
# Backlight percent for the HUD slider. `set N` writes the brightness.
set -u
if [ "${1:-}" = set ]; then
    brightnessctl set "${2%%.*}%" >/dev/null
    exit 0
fi
brightnessctl -m 2>/dev/null | awk -F, '{ gsub("%", "", $4); print int($4) }'
