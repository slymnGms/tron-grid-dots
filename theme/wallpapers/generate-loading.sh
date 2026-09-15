#!/usr/bin/env bash
# ============================================================================
# Generate GTA-V-style loading-screen parallax layers (gitignored PNGs).
# Wide canvases (2400x1200) so the idle overlay can Ken-Burns pan them.
# Geometric silhouettes only — no movie stills.
# ============================================================================
set -u

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OUT="$DIR/loading"
W=2400 H=1200
mkdir -p "$OUT"

IM="magick"; command -v magick >/dev/null 2>&1 || IM="convert"
command -v "$IM" >/dev/null 2>&1 || { echo "[loading] ImageMagick missing" >&2; exit 1; }

# perspective floor grid + distant towers
draw_bg() {
    local accent="$1"
    local vpx=$((W / 2)) vpy=$((H * 45 / 100))
    local x y step
    echo "fill #05080D rectangle 0,0 $W,$H"
    # sky scanlines
    for ((y = 0; y < vpy; y += 18)); do
        echo "stroke ${accent}18 line 0,$y $W,$y"
    done
    # vanishing-point floor
    for ((x = -400; x <= W + 400; x += 90)); do
        echo "stroke ${accent}28 line $x,$H $vpx,$vpy"
    done
    step=14
    for ((y = vpy; y <= H; y += step)); do
        echo "stroke ${accent}22 line 0,$y $W,$y"
        step=$((step + 8))
        [ "$step" -lt 70 ] || step=70
    done
    echo "stroke ${accent}90 strokewidth 3 line 0,$vpy $W,$vpy"
}

draw_mid() {
    local accent="$1"
    local x h base=$((H * 45 / 100))
    echo "fill none"
    # circuit "skyline" of data-towers along the horizon
    x=80
    while [ "$x" -lt "$W" ]; do
        h=$(( 40 + (x * 17 % 220) ))
        echo "stroke ${accent}55 strokewidth 2 fill ${accent}14 rectangle $x,$((base - h)) $((x + 18)),$base"
        x=$((x + 28 + (x * 13 % 50)))
    done
    # long light-ribbon
    echo "stroke ${accent}70 strokewidth 6 line 0,$((base + 40)) $W,$((base + 80))"
    echo "stroke ${accent}30 strokewidth 14 line 0,$((base + 40)) $W,$((base + 80))"
}

# Identity disc (1982)
draw_fg_disc() {
    local accent="$1"
    local cx=1880 cy=620
    echo "fill none stroke $accent strokewidth 22 circle $cx,$cy $cx,$((cy + 210))"
    echo "strokewidth 8 circle $cx,$cy $cx,$((cy + 150))"
    echo "strokewidth 3 circle $cx,$cy $cx,$((cy + 40))"
    echo "strokewidth 4 line $((cx - 210)),$cy $((cx + 210)),$cy"
    echo "line $cx,$((cy - 210)) $cx,$((cy + 210))"
}

# Light-cycle side profile (Legacy)
draw_fg_cycle() {
    local accent="$1"
    echo "fill ${accent}30 stroke $accent strokewidth 3"
    echo "polygon 1680,700 2140,700 2080,790 1710,790"
    echo "fill ${accent}50 polygon 1860,700 2080,700 2040,640 1900,640"
    echo "fill none strokewidth 6 circle 1760,810 1760,848"
    echo "circle 2060,810 2060,848"
    echo "strokewidth 10 line 1680,740 1280,740"
    echo "strokewidth 3 line 1680,755 1380,755"
}

# Recognizer (Uprising)
draw_fg_recognizer() {
    local accent="$1"
    echo "fill ${accent}22 stroke $accent strokewidth 3"
    echo "rectangle 1760,360 1835,1080"
    echo "rectangle 2085,360 2160,1080"
    echo "rectangle 1740,330 2180,410"
    echo "fill none strokewidth 5 circle 1970,370 1970,310"
}

# Gate / portal (Ares)
draw_fg_portal() {
    local accent="$1"
    echo "fill ${accent}18 stroke $accent strokewidth 5"
    echo "roundrectangle 1760,280 2180,1080 24,24"
    echo "fill none strokewidth 2 roundrectangle 1820,340 2120,1020 16,16"
    echo "strokewidth 8 line 1970,280 1970,200"
    echo "strokewidth 3 circle 1970,180 1970,155"
}

render_layer() {
    local out="$1" draw_fn="$2" accent="$3" canvas="${4:-transparent}"
    local draw
    [ "$canvas" = none ] && canvas=transparent
    draw="$("$draw_fn" "$accent")"
    "$IM" -size "${W}x${H}" "xc:$canvas" \
        -stroke "$accent" -strokewidth 1 \
        -draw "$draw" \
        "$out" || return 1
}

CYAN="#00E5FF"
ORANGE="#FF4A1C"

render_layer "$OUT/bg-cyan.png"   draw_bg         "$CYAN"   "#05080D" || exit 1
render_layer "$OUT/mid-cyan.png"  draw_mid        "$CYAN"   "none"    || exit 1
render_layer "$OUT/fg-disc.png"   draw_fg_disc    "$CYAN"   "none"    || exit 1
render_layer "$OUT/fg-cycle.png"  draw_fg_cycle   "$CYAN"   "none"    || exit 1

render_layer "$OUT/bg-orange.png"       draw_bg            "$ORANGE" "#05080D" || exit 1
render_layer "$OUT/mid-orange.png"      draw_mid           "$ORANGE" "none"    || exit 1
render_layer "$OUT/fg-recognizer.png"   draw_fg_recognizer "$ORANGE" "none"    || exit 1
render_layer "$OUT/fg-portal.png"       draw_fg_portal     "$ORANGE" "none"    || exit 1

echo "[loading] wrote parallax layers in $OUT"
