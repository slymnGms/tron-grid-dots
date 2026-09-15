#!/usr/bin/env bash
# Volume percent for the HUD slider. `set N` writes the sink volume.
set -u
if [ "${1:-}" = set ]; then
    pactl set-sink-volume @DEFAULT_SINK@ "${2%%.*}%"
    exit 0
fi
pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null |
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /%$/) { gsub("%", "", $i); print int($i); exit }
        }
    }'
