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
bash <(curl -fsSL https://raw.githubusercontent.com/slymnGms/tron-grid-dots/main/bootstrap.sh)
```

Manual:

```bash
sudo apt install git
git clone https://github.com/slymnGms/tron-grid-dots.git ~/.dotfiles/tron-grid-dots
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
| `--media` | `y` `n` | ask (suggests `y`) | Entertainment stack: RetroArch + libretro cores, ES-DE game frontend, Kodi. |
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
| `Super+grave` | Scratchpad terminal (one reused kitty) |
| `Super+Space` | Launcher (rofi) |
| `Super+Tab` | Window switcher (rofi) |
| `Super+?` | Keybind cheatsheet |
| `Super+D` | **HUD dashboard** (eww slide-in) |
| `Super+E` | File manager (ranger in kitty) |
| `Super+N` | Identity disc (`~/GRID/disc.md`) |
| `Super+G` | Games (ES-DE frontend) |
| `Super+M` | Theater (Kodi) |
| `Super+Q` / `Super+Shift+Q` | Close / kill window |
| `Super+F` | Fullscreen toggle |
| `Super+T` | Floating/tiled toggle |
| `Super+H J K L` | Focus window west/south/north/east |
| `Super+Shift+H J K L` | Swap window in direction |
| `Super+Ctrl+H J K L` | Resize window |
| `Super+1..6` | Focus sector (`I/O` `GRID` `ARENA` `TOWER` `SEA` `FLYNN`) |
| `Super+Shift+1..6` | Move window to sector |
| `Super+[` / `Super+]` | Previous / next sector |
| `Super+O` | Tablet rotate (screen + touch) |
| `Super+Shift+S` | Preview / dismiss idle overlay |
| `Super+Shift+D` | Cycle idle skin (tron → minimal → text → slides → loading) |
| `Super+Shift+C` / `Super+Shift+R` | Reload sxhkd / restart bspwm |
| `Super+Shift+E` | **END OF LINE** power menu |
| `Print` / `Shift+Print` | Screenshot full / region |
| `XF86 media keys` | Volume, brightness, playerctl |

The Openbox session mirrors the core binds (`Super+Return/Space/D/E/N/O/Q/F/grave/Tab`,
`Super+Shift+S/D`, `Super+1..4`, `Alt+Tab`).

## Idle overlay (Rainmeter-style skins)

The idle "screensaver" is an eww overlay (tap anywhere to resume) — not
xscreensaver, which blanks the rotated D330 with no dismiss UI. **Working
desktop wallpaper stays the generated grid.** Skins only apply while idle.

```bash
tron skin list          # shipped + user skins
tron skin next          # cycle tron → minimal → text → slides → loading
tron skin loading       # GTA V-style Tron movie/series cards
```

| Skin | Look |
|---|---|
| `tron` | Orbitron clock, accent chrome, dim overlay (default) |
| `minimal` | No boxes; clock center, weather top-right |
| `text` | TTY: JetBrainsMono on `#000000`, no CSS chrome |
| `slides` | Slideshow from `~/Pictures/tron-slides` + corner widgets |
| `loading` | GTA V loading-screen: letterbox, Ken Burns parallax, cycling **TRON / Legacy / Uprising / Ares** cards |

Drop JPG/PNG/WebP into `~/Pictures/tron-slides` for the `slides` skin.
Images are scaled once into `~/.cache/tron/slides/` so a 4K photo is not
decoded every tick.

Each skin is JSON (`config/skins/<name>.json`, or override in
`~/.config/tron/skins/`). Nine slots (`top-left` … `bottom-right`) and
widget types `clock` `date` `weather` `quote` `text` `music` `system`
`tag` `hint`. Background modes: `dim`, `color`, `slideshow`, `parallax`.
The `loading` skin uses `"layout": "loading"` instead of the 9-slot grid
(letterbox + three ImageMagick layers that pan at different speeds). Copy a
shipped file, change slots or cards, `tron skin yourname`.

## `tron` CLI

Linked to `~/.local/bin/tron`:

```
tron hud | rotate | display | update | skin | quote | power | scratch | binds | lowpower
```

`tron lowpower on` kills picom and the eww daemon (~80 MB back). Super+D
still opens the HUD on demand. `tron lowpower off` restores them.

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
| Dashboard | eww HUD: clock, weather, fetch, music, CPU/RAM/disk, volume/brightness, Wi-Fi, on-screen keyboard, idle-skin picker | ~55 MB (heaviest piece) |
| Launcher | rofi | 0 idle |
| Notifications | dunst | ~4 MB |
| Terminal | kitty (90% opacity, ligatures) | ~90 MB/window |
| Shell | fish + starship | — |
| TUI kit | fastfetch (custom TRON logo), btop (tron theme), tmux, neovim, ranger, lazygit, cava, ncdu, cmus, ani-cli | on demand |
| D330 extras | zram (zstd, 60%), `tron-rotate` tablet toggle, `tron lowpower` | — |
| Entertainment | RetroArch (ozone UI) + libretro cores from APT, ES-DE frontend (AppImage), Kodi (VAAPI decode) | 0 idle — launched on demand |

## Entertainment

Optional (`--media y`, or answer the prompt). A basic RetroPie-style couch
layer, not a deep build-out:

- **Games**: `Super+G` (or the HUD's GAMES button) opens **ES-DE**, which
  drives RetroArch cores. Drop ROMs into `~/ROMs/<system>/` — ES-DE creates
  the folder layout and explains it on first run. Installed cores: GB/GBC,
  GBA, NES, SNES, Genesis, PS1, N64 (N64: light titles only on the N4000;
  more cores via RetroArch's online updater).
- **Starter games** (all legally free): SuperTux (native Mario-style
  platformer, in the app launcher), plus homebrew ROMs pre-dropped into
  `~/ROMs` — Celeste Classic (GBA), µCity (GBC city builder), Libbet and
  the Magic Floor (GB). Commercial ROMs (Pokémon, Mario, …) are
  copyrighted and are **not** downloaded — dump your own cartridges and
  copy them into `~/ROMs/<system>/`.
- **Theater**: `Super+M` (or THEATER) opens **Kodi** — stock Estuary skin;
  add sources via Settings → Media. 1080p H.264/HEVC decodes in hardware
  (VAAPI) on the Gemini Lake iGPU.
- All three run borderless-fullscreen under bspwm automatically, and picom
  unredirects fullscreen windows, so emulation and video take no
  compositor penalty.

The HUD also exposes volume and brightness sliders, a Wi-Fi button
(`nmtui`), and an on-screen keyboard (`onboard`) — none of those daemons
run idle.

Theming: `theme/palette.sh` is the single source of truth.
`theme/apply.sh` generates per-app color files from it — include files
(`*.gen.*`, gitignored) for kitty/polybar/rofi/eww/dunst/tmux/fish, and
accent-swapped rendered copies for starship/fastfetch/btop/openbox-theme,
which have no include mechanism. bspwm and picom read the palette at
session start, and the wallpaper is generated from it with ImageMagick.
