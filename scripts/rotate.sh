#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — D330 screen orientation (bound to Super+O, linked as
# tron-rotate). The panel is physically 90° off: at xrandr "normal" the top
# bar sits on the left physical edge. Landscape home is --rotate right.
# Display only for the panel; touchscreen is mapped to that output so
# fingers follow a 90° CW rotate. Touchpad is left on identity.
#
#   tron-rotate                  toggle right (landscape) <-> normal (portrait)
#   tron-rotate right            set landscape home
#   tron-rotate --ensure         set right only if not already (login),
#                                then apply display policy (internal primary,
#                                second screen mirror or off — never extend)
#   tron-rotate --map-inputs     remap touchscreen to the panel (not touchpad)
#   tron-rotate --debug          remap and print which devices got a CTM
#   -q / --quiet                 no notification (session autostart)
# ============================================================================
set -u

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

display_bin() {
    # Prefer the sibling script even when git did not mark it +x (Windows
    # checkouts). Invoked with `bash` so execute-bit is not required.
    if [ -f "$HERE/display.sh" ]; then
        printf '%s\n' "$HERE/display.sh"
    elif [ -f /usr/local/bin/tron-display ]; then
        printf '%s\n' /usr/local/bin/tron-display
    elif command -v tron-display >/dev/null; then
        command -v tron-display
    fi
}

run_display() {
    local script
    script="$(display_bin)"
    [ -n "$script" ] || return 0
    bash "$script" "$@"
}

err() { printf 'rotate: %s\n' "$*" >&2; command -v notify-send >/dev/null && notify-send "ROTATE" "$*"; }

notify() {
    [ -n "${QUIET:-}" ] && return 0
    command -v notify-send >/dev/null && notify-send "ROTATE" "$*"
    return 0
}

TARGET=""
ENSURE=0
QUIET="${QUIET:-}"
for arg in "$@"; do
    case "$arg" in
        -q|--quiet) QUIET=1 ;;
        --ensure|ensure) ENSURE=1; TARGET="${TARGET:-right}" ;;
        --map-inputs|map-inputs) MAP_ONLY=1 ;;
        --debug|debug) DEBUG=1 ;;
        normal|left|right|inverted) TARGET="$arg" ;;
        -h|--help)
            printf 'usage: tron-rotate [-q] [--ensure] [--map-inputs] [--debug] [normal|left|right|inverted]\n'
            exit 0
            ;;
        *) err "usage: tron-rotate [-q] [--ensure] [--map-inputs] [--debug] [normal|left|right|inverted]"; exit 1 ;;
    esac
done

command -v xrandr >/dev/null || { err "xrandr not found"; exit 1; }

# Built-in panel only. USB-C power can list DP-1 as connected first.
OUTPUT=""
DISP="$(display_bin)"
if [ -n "$DISP" ]; then
    OUTPUT="$(run_display internal)" || OUTPUT=""
fi
if [ -z "$OUTPUT" ]; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        OUTPUT="$(xrandr --query | awk '
            $2 == "connected" {
                if ($1 ~ /^(eDP|DSI|LVDS)/) { print $1; found=1; exit }
                if (!first) first=$1
            }
            END { if (!found && first) print first }
        ')"
        [ -n "$OUTPUT" ] && break
        sleep 0.1
    done
fi
[ -n "$OUTPUT" ] || { err "no connected output found"; exit 1; }

# Word immediately before "(normal left inverted…" is the active rotation.
# Walking every token matched `left` from that supported-list and then
# applied the wrong touch matrix (finger right → cursor down).
CURRENT="$(xrandr --query | awk -v target="$OUTPUT" '
    $1 == target {
        if (match($0, / (normal|left|right|inverted) \(/)) {
            print substr($0, RSTART+1, RLENGTH-3)
            exit
        }
        print "normal"
    }')"
[ -n "$CURRENT" ] || CURRENT="right"

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/tron"
LOG="$LOG_DIR/rotate-inputs.log"
dbg() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    printf '%s\n' "$*" >>"$LOG" 2>/dev/null || true
    [ -n "${DEBUG:-}" ] && printf 'rotate: %s\n' "$*" >&2
}

# Touchpads/mice stay on identity. Digitizers get a CTM for the current
# xrandr rotate. libinput does not expose "Abs MT Position", and D330
# nodes are often named GDIX1001:00 / GXTP… rather than "touchscreen".
udev_flag() {
    local node="$1" key="$2"
    [ -n "$node" ] && command -v udevadm >/dev/null || return 1
    udevadm info --query=property --name="$node" 2>/dev/null | grep -qx "${key}=1"
}

device_node() {
    xinput list-props "$1" 2>/dev/null | awk -F'"' '/Device Node \(/ { print $2; exit }'
}

set_ctm() {
    local id="$1" matrix="$2"
    # shellcheck disable=SC2086
    xinput set-prop --type=float "$id" 'Coordinate Transformation Matrix' $matrix 2>/dev/null ||
        xinput set-prop "$id" 'Coordinate Transformation Matrix' $matrix
}

pointer_ids() {
    xinput list 2>/dev/null | sed -n 's/.*id=\([0-9][0-9]*\).*slave[[:space:]][[:space:]]*pointer.*/\1/p'
}

pointer_name() {
    xinput list 2>/dev/null | awk -v i="$1" '
        $0 ~ ("id=" i "[^0-9]") {
            gsub(/\t/, " ")
            sub(/^[^[:alnum:]]+/, "")
            sub(/[[:space:]]+id=.*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            print
            exit
        }'
}

is_touchpad() {
    local id="$1" name="$2" node="$3"
    printf '%s' "$name" | grep -qiE 'touchpad|trackpoint|trackball' && return 0
    udev_flag "$node" ID_INPUT_TOUCHPAD && return 0
    xinput list-props "$id" 2>/dev/null | grep -q 'libinput Tapping Enabled' && return 0
    return 1
}

is_touchscreen() {
    local id="$1" name="$2" node="$3"
    udev_flag "$node" ID_INPUT_TOUCHSCREEN && return 0
    udev_flag "$node" ID_INPUT_TABLET && return 0
    printf '%s' "$name" | grep -qiE 'touchscreen|digitizer|goodix|gdix|gxtp|silead|gsl|wacom|stylus|pen|finger' && return 0
    xinput list-props "$id" 2>/dev/null | grep -q 'Abs MT Position' && return 0
    return 1
}

reset_touchpads() {
    command -v xinput >/dev/null || return 0
    local id name node
    for id in $(pointer_ids); do
        name="$(pointer_name "$id")"
        node="$(device_node "$id")"
        is_touchpad "$id" "$name" "$node" || continue
        set_ctm "$id" "1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0" 2>/dev/null || true
        dbg "touchpad id=$id identity ($name)"
    done
}

map_touchscreens() {
    command -v xinput >/dev/null || return 0
    [ -n "$OUTPUT" ] || return 0
    local rot matrix id name node mapped=0
    rot="${1:-$CURRENT}"
    [ -n "$rot" ] || rot="right"
    case "$rot" in
        left)     matrix="0.0 -1.0 1.0 1.0 0.0 0.0 0.0 0.0 1.0" ;;
        right)    matrix="0.0 1.0 0.0 -1.0 0.0 1.0 0.0 0.0 1.0" ;;
        inverted) matrix="-1.0 0.0 1.0 0.0 -1.0 1.0 0.0 0.0 1.0" ;;
        *)        matrix="1.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0" ;;
    esac
    dbg "output=$OUTPUT rotation=$rot matrix=$matrix"
    for id in $(pointer_ids); do
        name="$(pointer_name "$id")"
        node="$(device_node "$id")"
        is_touchpad "$id" "$name" "$node" && continue
        is_touchscreen "$id" "$name" "$node" || {
            dbg "skip id=$id ($name) node=$node"
            continue
        }
        if set_ctm "$id" "$matrix"; then
            mapped=$((mapped + 1))
            dbg "touchscreen id=$id CTM $rot ($name) $node"
        else
            dbg "FAILED id=$id ($name) set-prop"
        fi
    done
    if [ "$mapped" -eq 0 ]; then
        dbg "no touchscreen got a CTM — xinput list:"
        xinput list >>"$LOG" 2>/dev/null || true
        [ -n "${DEBUG:-}" ] && xinput list >&2
        [ -z "${QUIET:-}" ] && err "no touchscreen found to remap (see $LOG)"
    fi
}

map_inputs() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    : >"$LOG" 2>/dev/null || true
    reset_touchpads
    map_touchscreens "${1:-}"
}

apply() {
    local next="$1"
    xrandr --output "$OUTPUT" --primary --rotate "$next" || { err "xrandr rotate failed"; exit 1; }
    map_inputs "$next"
    [ -n "$DISP" ] && run_display --quiet ensure || true
    notify "Display: $next"
}

# --debug alone remaps inputs; it must not toggle portrait/landscape.
if [ -n "${DEBUG:-}" ] && [ -z "$TARGET" ] && [ "$ENSURE" != 1 ]; then
    MAP_ONLY=1
fi

if [ -n "${MAP_ONLY:-}" ]; then
    map_inputs
    [ -n "${DEBUG:-}" ] && [ -f "$LOG" ] && cat "$LOG" >&2
    exit 0
fi

apply_policy() {
    map_inputs "$CURRENT"
    [ -n "$DISP" ] && run_display --quiet ensure || true
}

if [ -n "$TARGET" ]; then
    # login/autostart: skip the xrandr call if the panel is already home
    if [ "$ENSURE" = 1 ] && [ "$CURRENT" = "$TARGET" ]; then
        apply_policy
        exit 0
    fi
    apply "$TARGET"
    exit 0
fi

# D330 home is right (landscape). Super+O flips to normal (portrait) and back.
case "$CURRENT" in
    right) apply normal ;;
    *)     apply right ;;
esac
exit 0
