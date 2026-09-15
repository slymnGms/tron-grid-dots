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
    echo "stroke ${accent}90 strokewidth 1 line 0,$vpy $W,$vpy"
}

draw_mid() {
    local accent="$1"
    local x h base=$((H * 45 / 100))
    echo "fill none"
    # circuit "skyline" of data-towers along the horizon
    x=80
    while [ "$x" -lt "$W" ]; do
        h=$(( 40 + (x * 17 % 220) ))
        echo "stroke ${accent}55 strokewidth 1 fill ${accent}10 rectangle $x,$((base - h)) $((x + 10)),$base"
        x=$((x + 22 + (x * 13 % 50)))
    done
    # long light-ribbon
    echo "stroke ${accent}70 strokewidth 2 line 0,$((base + 40)) $W,$((base + 80))"
    echo "stroke ${accent}30 strokewidth 5 line 0,$((base + 40)) $W,$((base + 80))"
}

# Identity disc (1982)
draw_fg_disc() {
    local accent="$1"
    local cx=1880 cy=620
    echo "fill none stroke $accent strokewidth 6 circle $cx,$cy $cx,$((cy + 140))"
    echo "strokewidth 2 circle $cx,$cy $cx,$((cy + 95))"
    echo "strokewidth 1 circle $cx,$cy $cx,$((cy + 22))"
    echo "strokewidth 1 line $((cx - 140)),$cy $((cx + 140)),$cy"
    echo "line $cx,$((cy - 140)) $cx,$((cy + 140))"
}

# Light-cycle side profile (Legacy)
draw_fg_cycle() {
    local accent="$1"
    echo "fill ${accent}18 stroke $accent strokewidth 1"
    echo "polygon 1760,720 2080,720 2040,780 1780,780"
    echo "fill ${accent}28 polygon 1880,720 2040,720 2010,680 1910,680"
    echo "fill none strokewidth 2 circle 1810,798 1810,822"
    echo "circle 2020,798 2020,822"
    echo "strokewidth 3 line 1760,746 1480,746"
    echo "strokewidth 1 line 1760,756 1580,756"
}

# Recognizer (Uprising)
draw_fg_recognizer() {
    local accent="$1"
    echo "fill ${accent}12 stroke $accent strokewidth 1"
    echo "rectangle 1860,380 1900,980"
    echo "rectangle 2040,380 2080,980"
    echo "rectangle 1840,360 2100,400"
    echo "fill none strokewidth 2 circle 1970,380 1970,348"
}

# Gate / portal (Ares)
draw_fg_portal() {
    local accent="$1"
    echo "fill ${accent}10 stroke $accent strokewidth 2"
    echo "roundrectangle 1840,360 2100,980 12,12"
    echo "fill none strokewidth 1 roundrectangle 1875,400 2065,930 8,8"
    echo "strokewidth 2 line 1970,360 1970,310"
    echo "strokewidth 1 circle 1970,298 1970,284"
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
