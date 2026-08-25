#!/usr/bin/env bash
# ============================================================================
# tron-grid-dots — curl-able bootstrap.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/<me>/tron-grid-dots/main/bootstrap.sh)
#
# Installs git if missing, clones to ~/.dotfiles/tron-grid-dots, runs install.sh.
# ============================================================================
set -u

# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
GITHUB_USER="<me>"   # <-- REPLACE with your GitHub username before publishing
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

REPO_URL="https://github.com/${GITHUB_USER}/tron-grid-dots.git"
DEST="$HOME/.dotfiles/tron-grid-dots"

if [ "$GITHUB_USER" = "<me>" ]; then
    echo "bootstrap: edit GITHUB_USER in this script first (still set to <me>)." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "[bootstrap] installing git..."
    sudo apt-get update -qq && sudo apt-get install -y git || {
        echo "[bootstrap] ERROR: could not install git." >&2; exit 1; }
fi

if [ -d "$DEST/.git" ]; then
    echo "[bootstrap] repo already cloned, pulling latest..."
    git -C "$DEST" pull --ff-only || {
        echo "[bootstrap] ERROR: pull failed — resolve in $DEST manually." >&2; exit 1; }
else
    mkdir -p "$(dirname "$DEST")"
    git clone "$REPO_URL" "$DEST" || {
        echo "[bootstrap] ERROR: clone failed — check the URL and your network." >&2; exit 1; }
fi

exec bash "$DEST/install.sh" "$@"
