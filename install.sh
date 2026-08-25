#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — installer for Lubuntu (Ubuntu 24.x base, X11) on the
# Lenovo IdeaPad D330 (Celeron N4000/N4020, 4 GB RAM, eMMC).
#
# Idempotent: re-run any time. Never overwrites without a backup.
#
# Usage:
#   ./install.sh [--accent cyan|orange] [--wm bspwm|openbox]
#                [--login greetd|sddm|skip] [--yes] [--refresh] [--help]
#
#   --accent   primary accent color              (default: cyan)
#   --wm       which session the summary points you at; BOTH are installed
#                                                (default: bspwm)
#   --login    greetd+tuigreet (primary), themed SDDM, or leave login alone
#                                                (default: ask, suggest greetd)
#   --yes      non-interactive: accept all defaults, no prompts
#   --refresh  only backup+link configs, regenerate theme, relink bin scripts;
#              no packages, no login changes (used by scripts/update.sh)
#
# Deliberately NOT `set -e`: every step reports its own failure and the run
# continues, so one flaky download can't leave you with a silent half-install.
# Failures are collected and printed loudly at the end.
# ============================================================================
set -u

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONF="$REPO/config"
XDG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
FONTS="$HOME/.local/share/fonts"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

ACCENT="${ACCENT:-cyan}"
WM="${WM:-bspwm}"
LOGIN=""
ASSUME_YES=0
REFRESH_ONLY=0
FAILURES=()

# ------------------------------------------------------------------ ui ------
c_acc=$'\033[36m'; c_warn=$'\033[31m'; c_dim=$'\033[90m'; c_off=$'\033[0m'
say()  { printf '%s[tron]%s %s\n' "$c_acc" "$c_off" "$*"; }
warn() { printf '%s[tron] WARNING:%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
fail() { warn "$*"; FAILURES+=("$*"); }

# ask "question" "default" -> REPLY (default used when --yes or no tty)
ask() {
    local q="$1" def="$2"
    if [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ]; then REPLY="$def"; return; fi
    read -rp "$(printf '%s[?]%s %s [%s] ' "$c_acc" "$c_off" "$q" "$def")" REPLY
    REPLY="${REPLY:-$def}"
}

# ---------------------------------------------------------------- args ------
while [ $# -gt 0 ]; do
    case "$1" in
        --accent)  ACCENT="${2:?--accent needs cyan|orange}"; shift 2 ;;
        --wm)      WM="${2:?--wm needs bspwm|openbox}"; shift 2 ;;
        --login)   LOGIN="${2:?--login needs greetd|sddm|skip}"; shift 2 ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --refresh) REFRESH_ONLY=1; shift ;;
        --help|-h) sed -n '2,25p' "$0"; exit 0 ;;
        *) warn "unknown flag: $1 (see --help)"; exit 1 ;;
    esac
done
case "$ACCENT" in cyan|orange) ;; *) warn "--accent must be cyan or orange"; exit 1 ;; esac
case "$WM" in bspwm|openbox) ;; *) warn "--wm must be bspwm or openbox"; exit 1 ;; esac
export ACCENT

# ------------------------------------------------------------- environment --
detect_env() {
    CODENAME=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
        OS_ID="${ID:-unknown}"
    fi
    ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    say "detected: ${OS_ID:-?} ${CODENAME:-?} on $ARCH, accent=$ACCENT, wm=$WM"

    if [ "$REFRESH_ONLY" = 0 ]; then
        case "${OS_ID:-} ${ID_LIKE:-}" in
            *ubuntu*|*debian*) ;;
            *) warn "this targets Ubuntu/Lubuntu; proceeding anyway on '${OS_ID:-unknown}'" ;;
        esac
        if [ "$(printf '%s' "${XDG_SESSION_TYPE:-x11}")" = "wayland" ]; then
            warn "running under Wayland — this stack is X11-only; pick an X11 session after install"
        fi
    fi
}

# ---------------------------------------------------------------- apt -------
apt_install() {
    say "installing APT packages (one grouped transaction)..."
    # Grouped roughly by role; everything here exists in noble main/universe.
    local pkgs=(
        # session / wm
        bspwm sxhkd openbox obconf picom polybar rofi dunst feh xinit
        x11-xserver-utils xinput libnotify-bin
        # terminal / shell
        kitty fish tmux
        # tui tools
        neovim btop ncdu cava cmus ranger
        # helpers used by configs & scripts
        maim xclip playerctl brightnessctl pulseaudio-utils jq curl wget
        unzip xz-utils imagemagick wmctrl fontconfig git
        # ani-cli runtime deps
        mpv fzf aria2
        # eMMC-saving compressed swap
        zram-tools
        # eww runtime libs (usually present; cheap to state explicitly)
        libgtk-3-0t64
    )
    sudo apt-get update || { fail "apt update failed"; return 1; }
    sudo apt-get install -y "${pkgs[@]}" || fail "apt install failed — scroll up for the offending package"
}

# ------------------------------------------------- non-APT installs ---------
# Each of these is a release-binary install with its source URL stated.

install_nerd_font() {   # JetBrainsMono Nerd Font — github.com/ryanoasis/nerd-fonts
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        say "JetBrainsMono Nerd Font already installed"; return 0
    fi
    say "installing JetBrainsMono Nerd Font..."
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    mkdir -p "$FONTS/JetBrainsMonoNF"
    curl -fsSL "$url" -o /tmp/jbmono-nf.tar.xz &&
        tar -xJf /tmp/jbmono-nf.tar.xz -C "$FONTS/JetBrainsMonoNF" &&
        rm -f /tmp/jbmono-nf.tar.xz &&
        fc-cache -f "$FONTS" >/dev/null ||
        fail "JetBrainsMono Nerd Font install failed ($url)"
}

install_orbitron() {    # Orbitron — Google Fonts (google/fonts repo, OFL)
    if fc-list 2>/dev/null | grep -qi "Orbitron"; then
        say "Orbitron already installed"; return 0
    fi
    say "installing Orbitron..."
    local url="https://github.com/google/fonts/raw/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf"
    mkdir -p "$FONTS"
    curl -fsSL "$url" -o "$FONTS/Orbitron[wght].ttf" &&
        fc-cache -f "$FONTS" >/dev/null ||
        fail "Orbitron install failed ($url)"
}

install_starship() {    # starship — official installer (starship.rs)
    if command -v starship >/dev/null; then say "starship already installed"; return 0; fi
    say "installing starship prompt..."
    mkdir -p "$BIN"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN" ||
        fail "starship install failed (https://starship.rs/install.sh)"
}

install_eww() {         # eww — github.com/elkowar/eww (not in APT)
    if command -v eww >/dev/null; then say "eww already installed"; return 0; fi
    mkdir -p "$BIN"
    if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then
        say "installing eww from GitHub release binary..."
        local url
        url="$(curl -fsSL https://api.github.com/repos/elkowar/eww/releases/latest 2>/dev/null |
               jq -r '.assets[].browser_download_url' 2>/dev/null |
               grep -E '/eww$|x86_64.*linux' | head -1)"
        [ -z "$url" ] && url="https://github.com/elkowar/eww/releases/latest/download/eww"
        if curl -fsSL "$url" -o "$BIN/eww" && chmod +x "$BIN/eww" && "$BIN/eww" --version >/dev/null 2>&1; then
            say "eww $("$BIN/eww" --version 2>/dev/null) installed"
            return 0
        fi
        rm -f "$BIN/eww"
        warn "release binary didn't run; falling back to cargo build (slow on the N4000 — expect 30+ min)"
    fi
    # cargo fallback (also the path for non-amd64)
    ask "Build eww with cargo? Needs ~2 GB disk and a long compile (y/n)" "y"
    [ "$REPLY" = "y" ] || { fail "eww not installed (declined cargo build)"; return 1; }
    sudo apt-get install -y build-essential libgtk-3-dev libpango1.0-dev \
        libgdk-pixbuf-2.0-dev libcairo2-dev libglib2.0-dev libdbusmenu-gtk3-dev ||
        { fail "eww build deps failed"; return 1; }
    # pick up a cargo installed by a previous run of this script
    # shellcheck disable=SC1091
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    command -v cargo >/dev/null || {
        curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal &&
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    } || { fail "rustup install failed"; return 1; }
    # X11 feature ONLY — the default also builds the Wayland backend, which
    # needs gtk-layer-shell and is dead weight on this stack.
    # --locked: build with eww's own Cargo.lock; freshly-resolved deps break
    # (e.g. new glib crate vs old dbusmenu-glib: missing ObjectExt items).
    cargo install --locked --git https://github.com/elkowar/eww eww \
        --no-default-features --features x11 --root "$HOME/.local" ||
        fail "eww cargo build failed"
}

install_fastfetch() {   # fastfetch — apt in newer Ubuntus; deb release fallback
    if command -v fastfetch >/dev/null; then say "fastfetch already installed"; return 0; fi
    say "installing fastfetch..."
    if sudo apt-get install -y fastfetch 2>/dev/null; then return 0; fi
    warn "fastfetch not in APT for '$CODENAME' — using the GitHub release .deb"
    if [ "$ARCH" = "amd64" ]; then
        local url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb"
        curl -fsSL "$url" -o /tmp/fastfetch.deb &&
            sudo apt-get install -y /tmp/fastfetch.deb && rm -f /tmp/fastfetch.deb ||
            fail "fastfetch .deb install failed ($url)"
    else
        fail "fastfetch: no APT package and no .deb for arch $ARCH"
    fi
}

install_lazygit() {     # lazygit — github.com/jesseduffield/lazygit (not in noble)
    if command -v lazygit >/dev/null; then say "lazygit already installed"; return 0; fi
    say "installing lazygit..."
    if sudo apt-get install -y lazygit 2>/dev/null; then return 0; fi
    local ver url
    ver="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
           jq -r '.tag_name' | sed 's/^v//')"
    [ -n "$ver" ] && [ "$ver" != "null" ] || { fail "lazygit: couldn't resolve latest version"; return 1; }
    url="https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_x86_64.tar.gz"
    mkdir -p "$BIN"
    curl -fsSL "$url" -o /tmp/lazygit.tgz &&
        tar -xzf /tmp/lazygit.tgz -C /tmp lazygit &&
        install /tmp/lazygit "$BIN/lazygit" && rm -f /tmp/lazygit.tgz /tmp/lazygit ||
        fail "lazygit install failed ($url)"
}

install_anicli() {      # ani-cli — github.com/pystardust/ani-cli (plain script)
    if command -v ani-cli >/dev/null; then say "ani-cli already installed"; return 0; fi
    say "installing ani-cli..."
    mkdir -p "$BIN"
    curl -fsSL "https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli" \
        -o "$BIN/ani-cli" && chmod +x "$BIN/ani-cli" ||
        fail "ani-cli install failed"
}

install_tuigreet() {    # tuigreet — github.com/apognu/tuigreet (not in noble)
    if command -v tuigreet >/dev/null; then say "tuigreet already installed"; return 0; fi
    say "installing tuigreet..."
    if sudo apt-get install -y tuigreet 2>/dev/null; then return 0; fi
    local url
    url="$(curl -fsSL https://api.github.com/repos/apognu/tuigreet/releases/latest |
           jq -r '.assets[].browser_download_url' | grep 'x86_64$' | head -1)"
    [ -n "$url" ] || { fail "tuigreet: no x86_64 release asset found"; return 1; }
    curl -fsSL "$url" -o /tmp/tuigreet &&
        sudo install /tmp/tuigreet /usr/local/bin/tuigreet && rm -f /tmp/tuigreet ||
        fail "tuigreet install failed ($url)"
}

# ------------------------------------------------------ backup + link -------
backup_target() {
    local t="$1"
    [ -e "$t" ] || [ -L "$t" ] || return 0
    # already our symlink? then it's idempotent — leave it
    if [ -L "$t" ] && [[ "$(readlink -f "$t")" == "$REPO"* ]]; then return 1; fi
    mkdir -p "$BACKUP_DIR"
    mv "$t" "$BACKUP_DIR/" || { fail "could not back up $t"; return 2; }
    say "backed up $(basename "$t") -> $BACKUP_DIR/"
    return 0
}

link_configs() {
    say "linking configs into ~/.config ..."
    mkdir -p "$XDG"
    # NOTE: btop, fastfetch and starship.toml are NOT linked — they are
    # rendered copies written by theme/apply.sh (no include support / app
    # rewrites its own config). See theme/apply.sh header.
    local dirs=(bspwm sxhkd openbox picom polybar eww rofi dunst kitty fish tmux)

    if command -v stow >/dev/null 2>&1; then
        say "using GNU stow"
        local d
        for d in "${dirs[@]}"; do backup_target "$XDG/$d"; done
        stow -d "$REPO" -t "$XDG" --restow \
             --ignore='^(btop|fastfetch|starship\.toml)$' --ignore='themerc\.in' \
             config || fail "stow failed"
    else
        local d st
        for d in "${dirs[@]}"; do
            backup_target "$XDG/$d"; st=$?
            [ "$st" = 2 ] && continue                    # backup failed: don't touch
            [ "$st" = 1 ] && { say "· $d already linked"; continue; }
            ln -s "$CONF/$d" "$XDG/$d" && say "· linked $d" || fail "linking $d failed"
        done
    fi

    # user scripts on PATH
    mkdir -p "$BIN"
    ln -sf "$REPO/scripts/rotate.sh" "$BIN/tron-rotate"
    ln -sf "$REPO/scripts/update.sh" "$BIN/tron-update"
    chmod +x "$REPO"/scripts/*.sh "$REPO"/theme/*.sh "$REPO"/theme/wallpapers/*.sh \
             "$CONF"/eww/scripts/*.sh "$CONF"/polybar/launch.sh "$CONF"/bspwm/bspwmrc 2>/dev/null
    say "· linked tron-rotate, tron-update into ~/.local/bin"
}

# ------------------------------------------------------------- theming ------
apply_theme() {
    say "generating theme files (ACCENT=$ACCENT)..."
    ACCENT="$ACCENT" bash "$REPO/theme/apply.sh" || fail "theme generation failed"
}

# ---------------------------------------------------------------- zram ------
setup_zram() {
    say "configuring zram (compressed swap — spares the eMMC)..."
    sudo tee /etc/default/zramswap >/dev/null <<'EOF' || { fail "zram config write failed"; return 1; }
# tron-grid-dots: 4 GB machine -> ~2.4 GB compressed swap in RAM, zstd
ALGO=zstd
PERCENT=60
PRIORITY=100
EOF
    sudo systemctl enable --now zramswap.service 2>/dev/null ||
        sudo systemctl restart zramswap.service ||
        fail "zramswap service failed to start"
    # prefer zram over the eMMC aggressively
    echo 'vm.swappiness=150' | sudo tee /etc/sysctl.d/99-tron-zram.conf >/dev/null
    sudo sysctl -q -p /etc/sysctl.d/99-tron-zram.conf 2>/dev/null || true
}

# --------------------------------------------------------------- login ------
setup_login() {
    if [ -z "$LOGIN" ]; then
        ask "Login manager: greetd (TUI, recommended) / sddm (themed) / skip" "greetd"
        LOGIN="$REPLY"
    fi
    case "$LOGIN" in
        greetd) setup_greetd ;;
        sddm)   setup_sddm_theme ;;
        skip|*) say "leaving the login manager untouched" ;;
    esac
}

setup_greetd() {
    say "setting up greetd + tuigreet..."
    sudo apt-get install -y greetd || { fail "greetd apt install failed"; return 1; }
    install_tuigreet || return 1

    # render config (ANSI color name swap for orange mode)
    local src="$REPO/login/greetd/config.toml" tmp=/tmp/greetd-config.toml
    if [ "$ACCENT" = "orange" ]; then
        sed 's/=cyan/=red/g' "$src" > "$tmp"
    else
        cp "$src" "$tmp"
    fi
    if [ -f /etc/greetd/config.toml ] && ! sudo cmp -s "$tmp" /etc/greetd/config.toml; then
        sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak-$(date +%s)"
        say "backed up existing /etc/greetd/config.toml"
    fi
    sudo cp "$tmp" /etc/greetd/config.toml || { fail "writing /etc/greetd/config.toml failed"; return 1; }

    ask "Disable SDDM and enable greetd now? Takes effect on reboot (y/n)" "y"
    if [ "$REPLY" = "y" ]; then
        sudo systemctl disable sddm 2>/dev/null
        sudo systemctl enable greetd || { fail "enabling greetd failed"; return 1; }
        # /usr/sbin may not be on a user PATH; the Debian package puts it there
        local greetd_bin
        greetd_bin="$(command -v greetd || echo /usr/sbin/greetd)"
        echo "$greetd_bin" | sudo tee /etc/X11/default-display-manager >/dev/null
        say "greetd enabled — active after reboot (F2 at the greeter picks bspwm/Openbox)"
    else
        say "skipped switching; enable later with: sudo systemctl disable sddm && sudo systemctl enable greetd"
    fi
}

setup_sddm_theme() {
    say "installing the Sugar Candy SDDM theme variant..."
    sudo apt-get install -y qml-module-qtquick-controls2 qml-module-qtgraphicaleffects ||
        { fail "sddm theme QML deps failed"; return 1; }
    local dest=/usr/share/sddm/themes/sugar-candy
    if [ ! -d "$dest" ]; then
        sudo git clone --depth 1 https://framagit.org/MarianArlt/sddm-sugar-candy.git "$dest" ||
            { fail "sugar-candy clone failed"; return 1; }
    fi
    [ -f "$REPO/theme/wallpapers/tron-grid.png" ] &&
        sudo cp "$REPO/theme/wallpapers/tron-grid.png" "$dest/Backgrounds/tron-grid.png"
    if [ "$ACCENT" = "orange" ]; then
        sed 's/#00E5FF/#FF4A1C/g' "$REPO/login/sddm/theme.conf.user" | sudo tee "$dest/theme.conf.user" >/dev/null
    else
        sudo cp "$REPO/login/sddm/theme.conf.user" "$dest/theme.conf.user"
    fi
    printf '[Theme]\nCurrent=sugar-candy\n' | sudo tee /etc/sddm.conf.d/10-tron-theme.conf >/dev/null ||
        fail "writing sddm theme config failed"
    say "SDDM will use Sugar Candy + grid wallpaper on next boot"
}

# ------------------------------------------------------------ sessions ------
check_sessions() {
    local missing=0
    [ -f /usr/share/xsessions/bspwm.desktop ] || { warn "bspwm.desktop missing from /usr/share/xsessions"; missing=1; }
    ls /usr/share/xsessions/openbox*.desktop >/dev/null 2>&1 || { warn "openbox session file missing"; missing=1; }
    [ "$missing" = 0 ] && say "login sessions present: bspwm + openbox"
}

# ------------------------------------------------------------- summary ------
summary() {
    echo
    printf '%s╔══════════════════════════════════════════════════════════╗%s\n' "$c_acc" "$c_off"
    printf '%s║  END OF LINE — installation pass complete                ║%s\n' "$c_acc" "$c_off"
    printf '%s╚══════════════════════════════════════════════════════════╝%s\n' "$c_acc" "$c_off"
    cat <<EOF

  At the login screen : pick session "${WM}" (greetd: F2 cycles sessions)
  Accent              : $ACCENT   (recolor: ACCENT=orange tron-update, or
                        edit ~/.config/tron-accent and run theme/apply.sh)

  Core keys (full table in README.md — keep them in sync!):
    Super+Return   terminal (kitty)        Super+D      HUD dashboard
    Super+Space    launcher (rofi)         Super+O      rotate screen (tablet)
    Super+Q        close window            Super+F      fullscreen
    Super+1..6     desktops                Super+E      files (ranger)
    Super+Shift+R  restart bspwm           Super+Shift+E  logout
    Print          screenshot

  Update later        : tron-update   (= git pull + re-link + re-theme)
EOF
    [ -d "$BACKUP_DIR" ] && printf '  Old configs backed up to: %s\n' "$BACKUP_DIR"
    if [ "${#FAILURES[@]}" -gt 0 ]; then
        echo
        printf '%s  %d STEP(S) FAILED:%s\n' "$c_warn" "${#FAILURES[@]}" "$c_off"
        local f
        for f in "${FAILURES[@]}"; do printf '   %s·%s %s\n' "$c_warn" "$c_off" "$f"; done
        echo   "  Fix the causes above and re-run ./install.sh (it is idempotent)."
        exit 1
    fi
    echo
    say "reboot (or log out) and jack in, program."
}

# ================================================================= main =====
detect_env

if [ "$REFRESH_ONLY" = 1 ]; then
    link_configs
    apply_theme
    summary
    exit 0
fi

apt_install
install_nerd_font
install_orbitron
install_starship
install_eww
install_fastfetch
install_lazygit
install_anicli
link_configs
apply_theme
setup_zram
setup_login
check_sessions
summary
