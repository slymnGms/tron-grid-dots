#!/usr/bin/env bash
# Render an idle-overlay skin JSON into config/eww/mirror.gen.yuck.
#
#   skin-render.sh              render the active skin (~/.config/tron-skin)
#   skin-render.sh list         shipped + user skin ids
#   skin-render.sh next         cycle shipped skins
#   skin-render.sh NAME         persist NAME and render
set -u

REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
XDG="${XDG_CONFIG_HOME:-$HOME/.config}"
SHIPPED="$REPO/config/skins"
USER_SKINS="$XDG/tron/skins"
OUT="$REPO/config/eww/mirror.gen.yuck"
ACTIVE_FILE="$XDG/tron-skin"
SHIPPED_ORDER=(tron minimal text slides loading)

yuck_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

find_skin() {
    local name="$1" p
    for p in "$USER_SKINS/$name.json" "$SHIPPED/$name.json" "$XDG/skins/$name.json"; do
        if [ -r "$p" ]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

list_skins() {
    local f base
    {
        printf '%s\n' "${SHIPPED_ORDER[@]}"
        for f in "$USER_SKINS"/*.json "$SHIPPED"/*.json "$XDG"/skins/*.json; do
            [ -r "$f" ] || continue
            base="$(basename "$f" .json)"
            printf '%s\n' "$base"
        done
    } | awk 'NF && !seen[$0]++'
}

current_skin() {
    if [ -r "$ACTIVE_FILE" ]; then
        tr -d '[:space:]' <"$ACTIVE_FILE"
    else
        printf 'tron'
    fi
}

persist() {
    mkdir -p "$XDG"
    printf '%s\n' "$1" >"$ACTIVE_FILE"
}

hex_rgba() {
    local hex="${1#\#}" dim="${2:-1}"
    local r g b
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    printf 'rgba(%s, %s, %s, %s)' "$r" "$g" "$b" "$dim"
}

emit_widget() {
    local type="$1" content="$2"
    local esc
    esc="$(yuck_escape "$content")"
    case "$type" in
        clock)
            printf '            (label :class "mirror-clock" :text time)\n'
            ;;
        date)
            printf '            (label :class "mirror-date" :text date)\n'
            ;;
        weather)
            cat <<'EOF'
            (box :class "mirror-weather" :spacing 10 :space-evenly false :halign "center"
              (label :class "mirror-wicon" :text {weather.icon})
              (box :orientation "v" :space-evenly false
                (label :class "mirror-wtemp" :halign "start" :text {weather.temp})
                (label :class "mirror-wdesc" :halign "start" :text {weather.desc})))
EOF
            ;;
        quote)
            printf '            (label :class "mirror-quote" :limit-width 52 :halign "center" :text quote)\n'
            ;;
        text)
            printf '            (label :class "mirror-text" :limit-width 52 :text "%s")\n' "$esc"
            ;;
        music)
            cat <<'EOF'
            (box :orientation "v" :space-evenly false :halign "center"
              (label :class "mirror-music" :limit-width 40 :text {music.title})
              (label :class "mirror-artist" :limit-width 40 :text {music.artist}))
EOF
            ;;
        system)
            printf '            (label :class "mirror-system" :text "CPU ${round(EWW_CPU.avg, 0)}  RAM ${round(EWW_RAM.used_mem_perc, 0)}")\n'
            ;;
        tag)
            [ -n "$esc" ] || esc="// GRID IDLE //"
            printf '            (label :class "mirror-tag" :text "%s")\n' "$esc"
            ;;
        hint)
            [ -n "$esc" ] || esc="TAP ANYWHERE TO RESUME"
            printf '            (label :class "mirror-hint" :text "%s")\n' "$esc"
            ;;
        *)
            return 0
            ;;
    esac
}

slot_align() {
    case "$1" in
        top-left)      echo start start ;;
        top-center)    echo center start ;;
        top-right)     echo end start ;;
        center-left)   echo start center ;;
        center)        echo center center ;;
        center-right)  echo end center ;;
        bottom-left)   echo start end ;;
        bottom-center) echo center end ;;
        bottom-right)  echo end end ;;
        *)             echo center center ;;
    esac
}

emit_slot() {
    local json="$1" slot="$2"
    local halign valign type content
    read -r halign valign <<< "$(slot_align "$slot")"
    printf '          (box :class "slot slot-%s" :halign "%s" :valign "%s" :hexpand true :orientation "v" :space-evenly false :spacing 8\n' \
        "$slot" "$halign" "$valign"
    while IFS=$'\t' read -r type content; do
        [ -n "$type" ] || continue
        emit_widget "$type" "$content"
    done < <(jq -r --arg s "$slot" '
        (.widgets // [])[]
        | select((.slot // "center") == $s)
        | [(.type // ""), (.content // "")] | @tsv
    ' "$json")
    printf '          )\n'
}

finish_render() {
    local name="$1" style="$2"
    persist "$name"
    printf '[skin] %s (%s) -> %s\n' "$name" "$style" "$OUT"

    if [ -z "${TRON_SKIN_NO_RELOAD:-}" ] && command -v eww >/dev/null 2>&1 && eww ping >/dev/null 2>&1; then
        eww reload >/dev/null 2>&1 || true
        local flag="${XDG_STATE_HOME:-$HOME/.local/state}/tron/mirror-open"
        if [ -f "$flag" ] && [ "$(cat "$flag" 2>/dev/null)" = "1" ]; then
            eww open mirror >/dev/null 2>&1 || true
        fi
    fi
}

# GTA V loading-screen layout: letterbox + 3-layer Ken Burns + movie cards.
render_loading() {
    local name="$1" json="$2" style="$3"
    local tmp
    tmp="$(mktemp)"
    cat >"$tmp" <<'EOF'
;; GENERATED by scripts/skin-render.sh from loading.json — do not edit
(defwindow mirror
  :monitor 0
  :geometry (geometry :x "0" :y "0" :width "100%" :height "100%")
  :stacking "overlay"
  :windowtype "normal"
  :wm-ignore true
  (button :class "mirror style-loading bg-parallax" :onclick "scripts/mirror-toggle.sh hide"
    (box :class "load-root" :orientation "v" :hexpand true :vexpand true :space-evenly false
      (box :class "load-letter load-letter-top" :hexpand true :space-evenly true
        (label :class "load-studio" :halign "start" :text {load.studio})
        (label :class "load-clock" :halign "end" :text time))
      (overlay :class "load-stage" :hexpand true :vexpand true
        (box :class "load-layer load-bg" :hexpand true :vexpand true
             :style "background-image: url('${load.bg}'); background-repeat: no-repeat; background-size: cover; margin-left: ${load.bx}px; margin-top: ${load.by}px;")
        (box :class "load-layer load-mid" :hexpand true :vexpand true
             :style "background-image: url('${load.mid}'); background-repeat: no-repeat; background-size: cover; margin-left: ${load.mx}px; margin-top: ${load.my}px;")
        (box :class "load-layer load-fg" :hexpand true :vexpand true
             :style "background-image: url('${load.fg}'); background-repeat: no-repeat; background-size: cover; margin-left: ${load.fx}px; margin-top: ${load.fy}px;")
        (box :class "load-grade" :hexpand true :vexpand true)
        (box :class "load-copy" :halign "start" :valign "end" :orientation "v" :space-evenly false :spacing 4
          (label :class "load-year" :halign "start" :text {load.year})
          (label :class "load-title" :halign "start" :text {load.title})
          (label :class "load-sub" :halign "start" :text {load.sub})
          (label :class "load-line" :halign "start" :limit-width 42 :text {load.line})))
      (box :class "load-letter load-letter-bot" :hexpand true :orientation "v" :space-evenly false :spacing 6
        (label :class "load-tag" :halign "start" :text {load.tag})
        (scale :class "load-bar" :min 0 :max 100 :value {load.bar} :sensitive false :hexpand true)
        (box :space-evenly true :hexpand true
          (label :class "load-hint" :halign "start" :text "TAP ANYWHERE TO RESUME")
          (label :class "load-mark" :halign "end" :text {load.mark}))))))
EOF
    mkdir -p "$(dirname "$OUT")"
    mv "$tmp" "$OUT"
    finish_render "$name" "$style"
}

render() {
    local name="$1" json style mode dim color interval layout
    json="$(find_skin "$name")" || { echo "[skin] unknown skin: $name" >&2; return 1; }
    command -v jq >/dev/null 2>&1 || { echo "[skin] jq is required" >&2; return 1; }

    style="$(jq -r '.style // "tron"' "$json")"
    layout="$(jq -r '.layout // "slots"' "$json")"
    mode="$(jq -r '.background.mode // "dim"' "$json")"
    if [ "$layout" = loading ] || [ "$mode" = parallax ]; then
        render_loading "$name" "$json" "$style"
        return
    fi
    dim="$(jq -r '.background.dim // empty' "$json")"
    color="$(jq -r '.background.color // "#05080D"' "$json")"
    interval="$(jq -r '.background.interval // 20' "$json")"

    case "$mode" in
        slideshow) [ -n "$dim" ] || dim=0.35 ;;
        color)     [ -n "$dim" ] || dim=1 ;;
        *)         [ -n "$dim" ] || dim=0.92; mode=dim ;;
    esac

    local dim_style
    if [ "$mode" = color ]; then
        dim_style="background-color: $color;"
    else
        dim_style="background-color: $(hex_rgba "${color:-#05080D}" "$dim");"
        if [ "$mode" != slideshow ]; then
            dim_style="background-color: $(hex_rgba "#05080D" "$dim");"
        fi
    fi

    local tmp
    tmp="$(mktemp)"
    {
        printf ';; GENERATED by scripts/skin-render.sh from %s — do not edit\n' "$(basename "$json")"
        printf ';; interval hint for slideshow.sh: %s\n' "$interval"
        cat <<EOF
(defwindow mirror
  :monitor 0
  :geometry (geometry :x "0" :y "0" :width "100%" :height "100%")
  :stacking "overlay"
  :windowtype "normal"
  :wm-ignore true
  (button :class "mirror style-${style} bg-${mode}" :onclick "scripts/mirror-toggle.sh hide"
    (box :class "mirror-root" :orientation "v" :hexpand true :vexpand true
         :style {slideshow == "" ? "" : "background-image: url('\${slideshow}'); background-size: cover; background-position: center;"}
      (box :class "mirror-dim" :hexpand true :vexpand true :orientation "v" :space-evenly true
           :style "${dim_style}"
        (box :class "mirror-row top" :hexpand true :space-evenly true :valign "start"
EOF
        emit_slot "$json" top-left
        emit_slot "$json" top-center
        emit_slot "$json" top-right
        cat <<'EOF'
        )
        (box :class "mirror-row mid" :hexpand true :vexpand true :space-evenly true :valign "center"
EOF
        emit_slot "$json" center-left
        emit_slot "$json" center
        emit_slot "$json" center-right
        cat <<'EOF'
        )
        (box :class "mirror-row bot" :hexpand true :space-evenly true :valign "end"
EOF
        emit_slot "$json" bottom-left
        emit_slot "$json" bottom-center
        emit_slot "$json" bottom-right
        cat <<'EOF'
        )
EOF
        if [ "$mode" = slideshow ]; then
            cat <<'EOF'
        (label :class "mirror-hint drop-hint" :visible {slideshow == ""}
               :text "DROP IMAGES IN ~/Pictures/tron-slides")
EOF
        fi
        cat <<'EOF'
      ))))
EOF
    } >"$tmp"

    mkdir -p "$(dirname "$OUT")"
    mv "$tmp" "$OUT"
    finish_render "$name" "$style"
}

cycle_next() {
    local cur="$1" i next=tron
    for i in "${!SHIPPED_ORDER[@]}"; do
        if [ "${SHIPPED_ORDER[$i]}" = "$cur" ]; then
            next="${SHIPPED_ORDER[$(( (i + 1) % ${#SHIPPED_ORDER[@]} ))]}"
            printf '%s\n' "$next"
            return
        fi
    done
    printf '%s\n' "${SHIPPED_ORDER[0]}"
}

arg="${1:-}"
case "$arg" in
    "" ) render "$(current_skin)" ;;
    list)
        list_skins
        printf 'active: %s\n' "$(current_skin)" >&2
        ;;
    next)
        nxt="$(cycle_next "$(current_skin)")"
        render "$nxt"
        command -v notify-send >/dev/null && notify-send "SKIN" "$(echo "$nxt" | tr '[:lower:]' '[:upper:]')"
        ;;
    help|-h|--help)
        sed -n '2,10p' "$0"
        ;;
    *)
        render "$arg"
        ;;
esac
