#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — update: git pull, re-link, re-theme.
# Linked into ~/.local/bin as tron-update by install.sh.
# ============================================================================
set -u

REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"

if [ "$(id -u)" -eq 0 ]; then
    echo "[update] Do not run this with sudo. sudo cannot see ~/.local/bin, so" >&2
    echo "[update] 'sudo tron-update' looks like 'command not found'." >&2
    echo "[update] Run as your user; the script will ask for sudo when needed:" >&2
    echo "  tron-update" >&2
    echo "  bash $REPO/scripts/update.sh" >&2
    exit 1
fi

printf '\033[36m[update]\033[0m repo: %s\n' "$REPO"

if ! git -C "$REPO" pull --ff-only; then
    echo "[update] ERROR: git pull failed (local changes? diverged branch?)." >&2
    echo "[update] Resolve manually in $REPO, then re-run." >&2
    exit 1
fi

# --refresh: backup+relink configs and regenerate theme files, no package work
bash "$REPO/install.sh" --refresh --yes || exit 1

echo
echo "[update] done. Reload with Super+Shift+R (bspwm) or re-login."
