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
#   --refresh  only backup+link configs, regenerate theme, relink bin scripts,
#              and re-install D330 orientation (boot service + login ensure);
#              no packages, no login-manager changes (used by scripts/update.sh)
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
MEDIA=""
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
        --media)   MEDIA="${2:?--media needs y|n}"; shift 2 ;;
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
    # Releases after 0.9.1 ship no binaries, so scan the release list (newest
    # first) for the most recent one that has an x86_64 asset.
    local url
    url="$(curl -fsSL https://api.github.com/repos/apognu/tuigreet/releases |
           jq -r '.[].assets[].browser_download_url' | grep -m1 'x86_64$')"
    if [ -n "$url" ]; then
        say "using release binary: $url"
        curl -fsSL "$url" -o /tmp/tuigreet &&
            sudo install /tmp/tuigreet /usr/local/bin/tuigreet && rm -f /tmp/tuigreet &&
            return 0
        warn "tuigreet binary download failed, trying cargo"
    fi
    # cargo fallback (tuigreet is on crates.io); installed system-wide since
    # the _greetd user must be able to run it
    # shellcheck disable=SC1091
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    if command -v cargo >/dev/null; then
        cargo install --locked tuigreet --root /tmp/tuigreet-build &&
            sudo install /tmp/tuigreet-build/bin/tuigreet /usr/local/bin/tuigreet &&
            rm -rf /tmp/tuigreet-build && return 0
    fi
    fail "tuigreet install failed (no usable release asset, no cargo)"
    return 1
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
    ln -sf "$REPO/scripts/display.sh" "$BIN/tron-display"
    ln -sf "$REPO/scripts/update.sh" "$BIN/tron-update"
    chmod +x "$REPO"/scripts/*.sh "$REPO"/theme/*.sh "$REPO"/theme/wallpapers/*.sh \
             "$REPO"/login/greetd/tron-xstart "$REPO"/login/greetd/tron-xsession \
             "$CONF"/eww/scripts/*.sh "$CONF"/polybar/launch.sh "$CONF"/bspwm/bspwmrc 2>/dev/null
    say "· linked tron-rotate, tron-display, tron-update into ~/.local/bin"
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

# ------------------------------------------------------- entertainment ------
# RetroPie-style couch layer, kept basic: RetroArch + APT cores, ES-DE
# (EmulationStation Desktop Edition) as the game frontend, Kodi for media.
# Gemini Lake decodes 1080p in hardware (VAAPI), emulates well up to ~PS1.
setup_entertainment() {
    if [ -z "$MEDIA" ]; then
        ask "Install entertainment stack (RetroArch + cores, ES-DE, Kodi)? (y/n)" "y"
        MEDIA="$REPLY"
    fi
    [ "$MEDIA" = "y" ] || { say "skipping entertainment stack"; return 0; }

    say "installing entertainment base (kodi, retroarch)..."
    # libfuse2t64: AppImages need FUSE2; intel-media-va-driver: VAAPI decode
    sudo apt-get install -y kodi retroarch libfuse2t64 intel-media-va-driver ||
        { fail "entertainment apt install failed"; return 1; }
    sudo apt-get install -y retroarch-assets 2>/dev/null ||
        warn "retroarch-assets not available (menu icons may be plain)"

    # libretro cores, one by one — availability varies per Ubuntu release and
    # one missing name must not sink the rest. mupen64plus (N64) is included
    # but expect only lighter titles to be playable on the N4000.
    local core cores=(gambatte mgba nestopia snes9x genesisplusgx
                      beetle-psx mupen64plus)
    for core in "${cores[@]}"; do
        sudo apt-get install -y "libretro-$core" 2>/dev/null ||
            warn "core libretro-$core not in APT for '$CODENAME' (get it via RetroArch's online updater)"
    done

    # ES-DE AppImage from its GitLab package registry (not in APT)
    if [ ! -x "$BIN/es-de" ]; then
        say "installing ES-DE (EmulationStation Desktop Edition)..."
        local ver url
        ver="$(curl -fsSL 'https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/packages?order_by=created_at&sort=desc&per_page=20' |
               jq -r '[.[] | select(.name == "ES-DE_Stable")][0].version')"
        if [ -n "$ver" ] && [ "$ver" != "null" ]; then
            url="https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/packages/generic/ES-DE_Stable/${ver}/ES-DE_x64.AppImage"
            mkdir -p "$BIN"
            curl -fSL "$url" -o "$BIN/es-de" && chmod +x "$BIN/es-de" &&
                say "ES-DE $ver installed" ||
                fail "ES-DE download failed ($url)"
        else
            fail "ES-DE: could not resolve latest version (es-de.org for manual install)"
        fi
    else
        say "ES-DE already installed"
    fi

    # rofi/menu entry for ES-DE (kodi/retroarch ship their own .desktop)
    mkdir -p "$HOME/.local/share/applications" "$HOME/ROMs"
    cat > "$HOME/.local/share/applications/es-de.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=ES-DE (Games)
Comment=EmulationStation Desktop Edition
Exec=$BIN/es-de
Categories=Game;
EOF

    # seed RetroArch config ONCE (it rewrites its own config, never symlink):
    # ozone = the modern dark couch UI; threaded video helps the 2-core N4000
    if [ ! -f "$XDG/retroarch/retroarch.cfg" ]; then
        mkdir -p "$XDG/retroarch"
        cat > "$XDG/retroarch/retroarch.cfg" <<'EOF'
menu_driver = "ozone"
video_threaded = "true"
video_fullscreen = "true"
pause_nonactive = "true"
EOF
        say "seeded ~/.config/retroarch/retroarch.cfg (ozone UI, threaded video)"
    fi
    say "ROMs live in ~/ROMs — ES-DE creates per-system folders on first run"
    install_starter_games
}

# Free starter library so ES-DE isn't empty on first boot.
# NO commercial ROMs (Pokémon/Mario etc. are copyrighted — dump your own
# carts into ~/ROMs). These are legal, freely-licensed homebrew, pinned to
# release URLs verified at commit time, plus a native Mario-style platformer.
install_starter_games() {
    say "adding free starter games..."
    # SuperTux: the classic libre Mario-style platformer (native, from APT)
    sudo apt-get install -y supertux 2>/dev/null || warn "supertux install failed"

    local dir="$HOME/ROMs"
    mkdir -p "$dir/gb" "$dir/gbc" "$dir/gba"
    fetch_rom() {  # fetch_rom URL DEST-PATH
        [ -f "$2" ] && return 0
        curl -fsSL "$1" -o "$2" && say "· $(basename "$2")" ||
            warn "starter game download failed: $1"
    }
    # Celeste Classic — the renowned PICO-8 platformer, official free GBA port
    fetch_rom "https://github.com/JeffRuLz/Celeste-Classic-GBA/releases/download/v1.2/Celeste.Classic.v1.2.Homebrew.gba" \
              "$dir/gba/Celeste Classic.gba"
    # uCity — open-source SimCity-style city builder for Game Boy Color
    fetch_rom "https://github.com/AntonioND/ucity/releases/download/v1.3/ucity.gbc" \
              "$dir/gbc/uCity.gbc"
    # Libbet and the Magic Floor — polished free GB puzzle game
    fetch_rom "https://github.com/pinobatch/libbet/releases/download/v0.08/libbet.gb" \
              "$dir/gb/Libbet and the Magic Floor.gb"
}

# ---------------------------------------------------------- orientation ------
# D330 panel is physically 90° off. Boot rotates the console (fbcon + grub);
# login/X applies xrandr --rotate right only if that has not already happened.
setup_orient() {
    say "D330 orientation: 90° CW at boot, again at login if needed..."
    if ! command -v sudo >/dev/null; then
        fail "sudo not found; skipping system orientation"
        return 1
    fi

    sudo install -m 755 "$REPO/scripts/orient.sh" /usr/local/bin/tron-orient ||
        { fail "installing tron-orient failed"; return 1; }
    sudo install -m 755 "$REPO/scripts/rotate.sh" /usr/local/bin/tron-rotate ||
        { fail "installing tron-rotate helper failed"; return 1; }
    sudo install -m 755 "$REPO/scripts/display.sh" /usr/local/bin/tron-display ||
        { fail "installing tron-display helper failed"; return 1; }

    sudo install -m 644 "$REPO/login/orient/tron-orient.service" \
        /etc/systemd/system/tron-orient.service ||
        { fail "installing tron-orient.service failed"; return 1; }
    sudo install -m 644 "$REPO/login/orient/90-tron-orient.rules" \
        /etc/udev/rules.d/90-tron-orient.rules ||
        fail "installing udev orient rule failed"

    sudo mkdir -p /etc/X11/Xsession.d
    sudo install -m 644 "$REPO/login/orient/40tron-orient" \
        /etc/X11/Xsession.d/40tron-orient ||
        fail "installing Xsession.d orient hook failed"

    # kernel cmdline so the console is already rotated from the first VT
    local grub_d=/etc/default/grub.d grub_cfg=/etc/default/grub.d/tron-orient.cfg
    if [ -d /etc/default ] && command -v update-grub >/dev/null; then
        sudo mkdir -p "$grub_d"
        if ! sudo cmp -s "$REPO/login/orient/grub.cfg" "$grub_cfg" 2>/dev/null; then
            sudo cp "$REPO/login/orient/grub.cfg" "$grub_cfg" &&
                sudo update-grub >/dev/null &&
                say "· grub: fbcon=rotate:1 (takes effect next reboot)" ||
                fail "writing grub fbcon rotate failed"
        fi
    fi

    # greetd TUI: apply fbcon at greeter start if boot missed it
    if [ -f /lib/systemd/system/greetd.service ] ||
       [ -f /usr/lib/systemd/system/greetd.service ] ||
       [ -f /etc/systemd/system/greetd.service ]; then
        sudo mkdir -p /etc/systemd/system/greetd.service.d
        sudo cp "$REPO/login/greetd/greetd.service.d/rotate.conf" \
            /etc/systemd/system/greetd.service.d/90-tron-rotate.conf ||
            fail "installing greetd orient drop-in failed"
    fi

    # SDDM greeter (X before password): ensure, do not force-rotate
    local xsetup=/usr/share/sddm/scripts/Xsetup
    if [ -f "$xsetup" ]; then
        if grep -q 'tron-grid-dots D330' "$xsetup"; then
            sudo sed -i 's/tron-rotate --quiet right/tron-rotate --quiet --ensure/' "$xsetup" || true
        else
            printf '\n# tron-grid-dots D330 — 90° CW only if not already applied\n/usr/local/bin/tron-rotate --quiet --ensure || true\n' |
                sudo tee -a "$xsetup" >/dev/null
        fi
    fi

    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable tron-orient.service >/dev/null 2>&1 ||
        fail "enabling tron-orient.service failed"
    sudo systemctl restart tron-orient.service 2>/dev/null ||
        sudo systemctl start tron-orient.service 2>/dev/null ||
        fail "starting tron-orient.service failed"
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger --subsystem-match=graphics --action=add 2>/dev/null || true
    say "· boot service enabled (tron-orient); login will no-op if already right"
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

    # logging session wrapper + login-time ensure (see login/greetd/)
    sudo install "$REPO/login/greetd/tron-xstart" /usr/local/bin/tron-xstart ||
        { fail "installing tron-xstart wrapper failed"; return 1; }
    sudo install "$REPO/login/greetd/tron-xsession" /usr/local/bin/tron-xsession ||
        { fail "installing tron-xsession wrapper failed"; return 1; }

    # if boot rotation did not stick, apply fbcon again just before tuigreet
    sudo mkdir -p /etc/systemd/system/greetd.service.d
    sudo cp "$REPO/login/greetd/greetd.service.d/rotate.conf" \
        /etc/systemd/system/greetd.service.d/90-tron-rotate.conf ||
        { fail "installing greetd rotate drop-in failed"; return 1; }
    sudo systemctl daemon-reload 2>/dev/null || true

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

    # Debian's Xorg wrapper only lets "console users" start X; the startx
    # launched from a greetd session (and especially inside VMs) can fail
    # that check and leave a Qt/X-less boot console. Loosen it.
    printf 'allowed_users=anybody\nneeds_root_rights=yes\n' |
        sudo tee /etc/X11/Xwrapper.config >/dev/null ||
        fail "writing /etc/X11/Xwrapper.config failed"

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
    Super+G        games (ES-DE)           Super+M        theater (Kodi)
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
    setup_orient
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
setup_entertainment
setup_orient
setup_login
check_sessions
summary
