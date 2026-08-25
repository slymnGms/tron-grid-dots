# tron-grid-dots

A minimal **Tron: Legacy / Ares command-center desktop** for weak hardware:
near-black grid wallpaper, thin neon borders, a slide-in HUD dashboard
(clock, weather, music, system rings) and a terminal-first workflow — built
on a light X11 stack (bspwm + polybar + eww) instead of Wayland/Hyprland,
and recolorable system-wide by changing **one variable**.

> **Tested on:** Lubuntu 24.04 (X11), Lenovo IdeaPad D330, Celeron N4000,
> 4 GB RAM, 64 GB eMMC. Everything idles in tens of MB, not hundreds.

![screenshot placeholder](docs/screenshot.png)
*(screenshot placeholder — add `docs/screenshot.png` after first boot)*

## Install

One line on a fresh machine (installs git, clones to
`~/.dotfiles/tron-grid-dots`, runs the installer):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<me>/tron-grid-dots/main/bootstrap.sh)
```

Manual:

```bash
sudo apt install git
git clone https://github.com/suleymangumus/tron-grid-dots.git ~/.dotfiles/tron-grid-dots
cd ~/.dotfiles/tron-grid-dots
./install.sh                      # add --yes for zero prompts
```

The installer is **idempotent** and **never overwrites without a backup**
(existing configs go to `~/.config-backup-<timestamp>/`). It installs APT
packages in one transaction, then the non-APT pieces (eww, starship,
fastfetch fallback, tuigreet, JetBrainsMono Nerd Font, Orbitron, ani-cli,
lazygit) from their upstream releases, links `config/*` into `~/.config`
(GNU stow if present, plain symlinks otherwise), generates all color files
from `theme/palette.sh`, sets up zram, and offers the login-manager switch.

## Options

| Flag / env | Values | Default | What it does |
|---|---|---|---|
| `--accent` / `ACCENT` | `cyan` `orange` | `cyan` | `cyan` = Legacy (orange only for warnings). `orange` = Ares (swapped). |
| `--wm` / `WM` | `bspwm` `openbox` | `bspwm` | Both sessions are installed; this picks which one the summary/docs point at. Openbox = floating, touch/tablet-friendly. |
| `--login` | `greetd` `sddm` `skip` | ask (suggests `greetd`) | greetd+tuigreet TUI login (`IDENTIFY YOURSELF, PROGRAM`), themed SDDM (Sugar Candy), or hands off. |
| `--yes` | | | Non-interactive, accept defaults. |
| `--refresh` | | | Only re-link + re-theme (what `tron-update` uses). |

**Recolor everything later** — one variable, no other edits:

```bash
ACCENT=orange tron-update
```

## Keybinds (bspwm — keep in sync with `config/sxhkd/sxhkdrc`)

| Keys | Action |
|---|---|
| `Super+Return` | Terminal (kitty) |
| `Super+Space` | Launcher (rofi) |
| `Super+D` | **HUD dashboard** (eww slide-in) |
| `Super+E` | File manager (ranger in kitty) |
| `Super+Q` / `Super+Shift+Q` | Close / kill window |
| `Super+F` | Fullscreen toggle |
| `Super+T` | Floating/tiled toggle |
| `Super+H J K L` | Focus window west/south/north/east |
| `Super+Shift+H J K L` | Swap window in direction |
| `Super+Ctrl+H J K L` | Resize window |
| `Super+1..6` | Focus desktop |
| `Super+Shift+1..6` | Move window to desktop |
| `Super+[` / `Super+]` | Previous / next desktop |
| `Super+O` | Tablet rotate (screen + touch) |
| `Super+Shift+C` / `Super+Shift+R` | Reload sxhkd / restart bspwm |
| `Super+Shift+E` | Quit bspwm (logout) |
| `Print` / `Shift+Print` | Screenshot full / region |
| `XF86 media keys` | Volume, brightness, playerctl |

The Openbox session mirrors the core binds (`Super+Return/Space/D/E/O/Q/F`,
`Super+1..4`, `Alt+Tab`).

## Update

```bash
tron-update        # = git pull --ff-only + re-link + regenerate theme
```

## What's inside

| Piece | Tool | Idle cost (approx) |
|---|---|---|
| Login | greetd + tuigreet (SDDM variant optional) | 0 after login |
| WM | bspwm + sxhkd (alt: openbox for tablet) | ~3 MB |
| Compositor | picom (xrender, **no blur**) | ~30 MB |
| Bar | polybar | ~25 MB |
| Dashboard | eww HUD: clock, weather (wttr.in/Open-Meteo), fetch, playerctl music, CPU/RAM/disk rings | ~55 MB (heaviest piece) |
| Launcher | rofi | 0 idle |
| Notifications | dunst | ~4 MB |
| Terminal | kitty (90% opacity, ligatures) | ~90 MB/window |
| Shell | fish + starship | — |
| TUI kit | fastfetch (custom TRON logo), btop (tron theme), tmux, neovim, ranger, lazygit, cava, ncdu, cmus, ani-cli | on demand |
| D330 extras | zram (zstd, 60%), `tron-rotate` tablet toggle | — |

Theming: `theme/palette.sh` is the single source of truth.
`theme/apply.sh` generates per-app color files from it — include files
(`*.gen.*`, gitignored) for kitty/polybar/rofi/eww/dunst/tmux/fish, and
accent-swapped rendered copies for starship/fastfetch/btop/openbox-theme,
which have no include mechanism. bspwm and picom read the palette at
session start, and the wallpaper is generated from it with ImageMagick.
