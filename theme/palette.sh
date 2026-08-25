# shellcheck shell=bash
# ============================================================================
# tron-grid-dots — single source of truth for every color in the system.
# Change ACCENT (cyan|orange) and re-run theme/apply.sh (or install.sh
# --refresh) to recolor everything.
#
# Sourced by: theme/apply.sh, config/bspwm/bspwmrc, scripts, wallpapers.
# ============================================================================

# Accent resolution order: $ACCENT env var > ~/.config/tron-accent > cyan
if [ -z "${ACCENT:-}" ] && [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/tron-accent" ]; then
    ACCENT="$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/tron-accent")"
fi
ACCENT="${ACCENT:-cyan}"
export ACCENT

# --- Base tokens (spec) ------------------------------------------------------
export TRON_BG="#05080D"        # near-black background
export TRON_BG_ALT="#0A1017"    # card / bar background
export TRON_FG="#C8D6E0"        # main text
export TRON_FG_DIM="#4A6070"    # muted text / inactive borders
export TRON_CYAN="#00E5FF"      # Legacy accent / glow
export TRON_CYAN_SOFT="#6FC3DF" # softer cyan
export TRON_ORANGE="#FF4A1C"    # Ares accent / warnings
export TRON_ORANGE_SOFT="#FF8A5C" # derived soft orange (not in spec, needed for symmetry)

# --- Resolved accent ---------------------------------------------------------
# ACCENT=cyan  -> cyan is primary, orange marks warnings/active-alerts
# ACCENT=orange -> swapped (Ares mode)
if [ "$ACCENT" = "orange" ]; then
    export TRON_ACCENT="$TRON_ORANGE"
    export TRON_ACCENT_SOFT="$TRON_ORANGE_SOFT"
    export TRON_ACCENT_ALT="$TRON_CYAN"       # the "other" accent
    export TRON_WARN="$TRON_CYAN"
    export TRON_OK="$TRON_ORANGE"
    export TRON_ANSI_ACCENT="red"             # nearest ANSI name (tuigreet only)
else
    export TRON_ACCENT="$TRON_CYAN"
    export TRON_ACCENT_SOFT="$TRON_CYAN_SOFT"
    export TRON_ACCENT_ALT="$TRON_ORANGE"
    export TRON_WARN="$TRON_ORANGE"
    export TRON_OK="$TRON_CYAN"
    export TRON_ANSI_ACCENT="cyan"
fi

# --- Helpers -----------------------------------------------------------------
# hex_to_rgb "#00E5FF" -> "0 229 255"
hex_to_rgb() {
    local h="${1#\#}"
    printf '%d %d %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# hex_to_rgb_frac "#00E5FF" -> "0.00 0.90 1.00"  (for picom shadow flags)
hex_to_rgb_frac() {
    local h="${1#\#}"
    awk -v r="$((16#${h:0:2}))" -v g="$((16#${h:2:2}))" -v b="$((16#${h:4:2}))" \
        'BEGIN { printf "%.2f %.2f %.2f", r/255, g/255, b/255 }'
}
