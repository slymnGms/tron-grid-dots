#!/usr/bin/env bash
# Active idle-skin id for the HUD label.
set -u
f="${XDG_CONFIG_HOME:-$HOME/.config}/tron-skin"
if [ -r "$f" ]; then tr -d '[:space:]' <"$f"; else printf 'tron\n'; fi
