#!/usr/bin/env bash
# eww defpoll: GTA-V-style Ken Burns offsets + cycling Tron movie/series cards.
# Cheap when the active skin is not `loading` (one file read, static JSON).
set -u

XDG="${XDG_CONFIG_HOME:-$HOME/.config}"
OFF='{"on":false,"bg":"","mid":"","fg":"","bx":0,"mx":0,"fx":0,"by":0,"my":0,"fy":0,"title":"","sub":"","year":"","tag":"","line":"","mark":"","studio":"","bar":0}'

name="tron"
[ -r "$XDG/tron-skin" ] && name="$(tr -d '[:space:]' <"$XDG/tron-skin")"

EWW_DIR="$(readlink -f "${XDG}/eww" 2>/dev/null || true)"
REPO=""
if [ -n "$EWW_DIR" ]; then
    REPO="$(dirname "$(dirname "$EWW_DIR")")"
fi
[ -n "$REPO" ] && [ -d "$REPO/config/skins" ] || \
    REPO="$(dirname "$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")")"

json=""
for p in "$XDG/tron/skins/${name}.json" "$REPO/config/skins/${name}.json" "$XDG/skins/${name}.json"; do
    [ -r "$p" ] || continue
    json="$p"
    break
done
[ -n "$json" ] || { printf '%s\n' "$OFF"; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '%s\n' "$OFF"; exit 0; }

layout="$(jq -r '.layout // "slots"' "$json")"
mode="$(jq -r '.background.mode // ""' "$json")"
if [ "$layout" != loading ] && [ "$mode" != parallax ]; then
    printf '%s\n' "$OFF"
    exit 0
fi

LAY="$REPO/theme/wallpapers/loading"
if [ ! -f "$LAY/bg-cyan.png" ] && [ -f "$REPO/theme/wallpapers/generate-loading.sh" ]; then
    bash "$REPO/theme/wallpapers/generate-loading.sh" >/dev/null 2>&1 || true
fi

hold="$(jq -r '.background.hold // 14' "$json")"
[ "$hold" -ge 6 ] 2>/dev/null || hold=14
n="$(jq -r '.cards | length' "$json")"
[ "$n" -gt 0 ] 2>/dev/null || { printf '%s\n' "$OFF"; exit 0; }

# tenths of a second if GNU date supports %3N; else whole seconds
if now="$(date +%s%3N 2>/dev/null)" && [ "${#now}" -ge 12 ]; then
    sec="${now:0:10}"
    ms="${now:10:3}"
    t="${sec}.${ms}"
else
    t="$(date +%s).0"
fi

idx="$(awk -v t="$t" -v h="$hold" -v n="$n" 'BEGIN { printf "%d", (int(t / h) % n) }')"
bar="$(awk -v t="$t" -v h="$hold" 'BEGIN {
    f = t / h; f = f - int(f)
    printf "%d", f * 100
}')"

# slow sine pans — different amplitudes/phases per layer (Ken Burns, not 60fps shake)
read -r bx mx fx by my fy <<EOF
$(awk -v t="$t" 'BEGIN {
    pi = 3.14159265
    p = t / 18.0 * 2 * pi
    printf "%d %d %d %d %d %d",
        sin(p) * 28,
        sin(p * 1.18 + 0.5) * 52,
        sin(p * 1.4 + 1.1) * 76,
        cos(p * 0.7) * 8,
        cos(p * 0.9 + 0.3) * 12,
        cos(p * 1.1 + 0.8) * 16
}')
EOF
bx=${bx:-0}; mx=${mx:-0}; fx=${fx:-0}
by=${by:-0}; my=${my:-0}; fy=${fy:-0}

palette="$(jq -r --argjson i "$idx" '.cards[$i].palette // "cyan"' "$json")"
fgid="$(jq -r --argjson i "$idx" '.cards[$i].fg // "disc"' "$json")"
case "$palette" in orange) pal=orange ;; *) pal=cyan ;; esac

uri() {
    local f="$1"
    [ -f "$f" ] && printf 'file://%s' "$f" || printf ''
}

bg="$(uri "$LAY/bg-${pal}.png")"
mid="$(uri "$LAY/mid-${pal}.png")"
fg="$(uri "$LAY/fg-${fgid}.png")"

jq -cn \
    --arg bg "$bg" --arg mid "$mid" --arg fg "$fg" \
    --argjson bx "$bx" --argjson mx "$mx" --argjson fx "$fx" \
    --argjson by "$by" --argjson my "$my" --argjson fy "$fy" \
    --argjson bar "$bar" \
    --arg title "$(jq -r --argjson i "$idx" '.cards[$i].title // "TRON"' "$json")" \
    --arg sub   "$(jq -r --argjson i "$idx" '.cards[$i].sub // ""' "$json")" \
    --arg year  "$(jq -r --argjson i "$idx" '.cards[$i].year // ""' "$json")" \
    --arg tag   "$(jq -r --argjson i "$idx" '.cards[$i].tag // ""' "$json")" \
    --arg line  "$(jq -r --argjson i "$idx" '.cards[$i].line // ""' "$json")" \
    --arg mark  "$(jq -r --argjson i "$idx" '.cards[$i].mark // ""' "$json")" \
    --arg studio "$(jq -r '.studio // "ENCOM PRESENTS"' "$json")" \
    '{on:true, bg:$bg, mid:$mid, fg:$fg,
      bx:$bx, mx:$mx, fx:$fx, by:$by, my:$my, fy:$fy, bar:$bar,
      title:$title, sub:$sub, year:$year, tag:$tag, line:$line,
      mark:$mark, studio:$studio}'
