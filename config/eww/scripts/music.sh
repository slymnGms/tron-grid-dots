#!/usr/bin/env bash
# Music info for the HUD card, driven by playerctl (works with cmus via
# playerctld/mpris, mpv with mpris script, browsers, etc).
# deflisten: emits one JSON line per track/state change, forever.

command -v playerctl >/dev/null 2>&1 || {
    echo '{"status":"none","title":"PLAYERCTL MISSING","artist":"--"}'
    exit 0
}

# jq -R guarantees valid JSON even with quotes/backslashes in titles
emit() {
    jq -cn --arg s "$1" --arg t "$2" --arg a "$3" \
        '{status:$s, title:(if $t=="" then "NO SIGNAL" else $t end),
          artist:(if $a=="" then "--" else $a end)}'
}

emit "$(playerctl status 2>/dev/null)" \
     "$(playerctl metadata title 2>/dev/null)" \
     "$(playerctl metadata artist 2>/dev/null)"

playerctl --follow metadata --format '{{status}}\x1f{{title}}\x1f{{artist}}' 2>/dev/null |
while IFS=$'\x1f' read -r status title artist; do
    emit "$status" "$title" "$artist"
done

# playerctl exits when no players remain; keep the listener alive
while :; do
    echo '{"status":"none","title":"NO SIGNAL","artist":"--"}'
    sleep 5
    exec "$0"
done
