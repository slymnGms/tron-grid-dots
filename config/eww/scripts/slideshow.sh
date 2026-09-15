#!/usr/bin/env bash
# eww defpoll helper: current idle-slideshow frame as file:// URL, or empty.
# Scales into ~/.cache/tron/slides so a 4K photo is not decoded every tick.
set -u

XDG="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tron/slides"
mkdir -p "$CACHE"

EWW_DIR="$(readlink -f "${XDG}/eww" 2>/dev/null || true)"
REPO=""
if [ -n "$EWW_DIR" ]; then
    REPO="$(dirname "$(dirname "$EWW_DIR")")"
fi
[ -n "$REPO" ] && [ -d "$REPO/config/skins" ] || REPO="$(dirname "$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")")"

name="tron"
[ -r "$XDG/tron-skin" ] && name="$(tr -d '[:space:]' <"$XDG/tron-skin")"

json=""
for p in "$XDG/tron/skins/${name}.json" "$REPO/config/skins/${name}.json" "$XDG/skins/${name}.json"; do
    if [ -r "$p" ]; then json="$p"; break; fi
done
[ -n "$json" ] || { printf '\n'; exit 0; }

command -v jq >/dev/null 2>&1 || { printf '\n'; exit 0; }

mode="$(jq -r '.background.mode // "dim"' "$json")"
[ "$mode" = slideshow ] || { printf '\n'; exit 0; }

dir="$(jq -r '.background.dir // "~/Pictures/tron-slides"' "$json")"
dir="${dir/#\~/$HOME}"
interval="$(jq -r '.background.interval // 20' "$json")"
[ "$interval" -ge 5 ] 2>/dev/null || interval=20

[ -d "$dir" ] || { printf '\n'; exit 0; }

mapfile -t imgs < <(find "$dir" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
    \) 2>/dev/null | LC_ALL=C sort)

n=${#imgs[@]}
[ "$n" -gt 0 ] || { printf '\n'; exit 0; }

idx=$(( ($(date +%s) / interval) % n ))
src="${imgs[$idx]}"

# cache key: inode+mtime+size so a replaced file is re-scaled
stat_id="$(stat -c '%i-%Y-%s' "$src" 2>/dev/null || echo x)"
hash="$(printf '%s' "$stat_id" | sha256sum 2>/dev/null | awk '{print $1}')"
[ -n "$hash" ] || hash="$(printf '%s' "$stat_id" | md5sum | awk '{print $1}')"
out="$CACHE/${hash}.jpg"

if [ ! -f "$out" ]; then
    IM="magick"
    command -v magick >/dev/null 2>&1 || IM="convert"
    if command -v "$IM" >/dev/null 2>&1; then
        "$IM" "$src" -resize '1920x1200^' -gravity center -extent 1920x1200 "$out" 2>/dev/null || cp "$src" "$out"
    else
        cp "$src" "$out"
    fi
fi

printf 'file://%s\n' "$out"
