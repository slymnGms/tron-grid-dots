#!/usr/bin/env bash
# ============================================================================
# Generate the Tron grid wallpaper as a PNG (gitignored — always generated).
#
# Draws a faint accent grid on near-black with a subtle glow line at the
# horizon. Sized 1920x1200 (IdeaPad D330 FHD panel); feh scales it fine on
# the 1280x800 variant too. Needs ImageMagick (magick or convert).
# ============================================================================
set -u

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=../palette.sh
. "$DIR/../palette.sh"

OUT="$DIR/tron-grid.png"
W=1920 H=1200 STEP=64

IM="magick"; command -v magick >/dev/null 2>&1 || IM="convert"

# Build the draw commands: full grid at ~7% accent opacity, brighter line at
# the horizon (2/3 down), soft vignette darkening toward the top.
draw_grid() {
    local x y
    for ((x = 0; x <= W; x += STEP)); do echo "line $x,0 $x,$H"; done
    for ((y = 0; y <= H; y += STEP)); do echo "line 0,$y $W,$y"; done
}

HORIZON=$((H * 2 / 3))

"$IM" -size "${W}x${H}" "xc:$TRON_BG" \
    -stroke "${TRON_ACCENT}12" -strokewidth 1 -draw "$(draw_grid)" \
    -stroke "${TRON_ACCENT}55" -strokewidth 2 -draw "line 0,$HORIZON $W,$HORIZON" \
    -stroke "${TRON_ACCENT}22" -strokewidth 4 -draw "line 0,$HORIZON $W,$HORIZON" \
    "$OUT" || { echo "[wallpaper] ImageMagick failed" >&2; exit 1; }

echo "[wallpaper] wrote $OUT"
