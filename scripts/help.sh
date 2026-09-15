#!/usr/bin/env bash
# Keybind cheatsheet as a rofi list (Super+?).
set -u
REPO="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")"
FILE="$REPO/config/keybinds.txt"
[ -r "$FILE" ] || FILE="${XDG_CONFIG_HOME:-$HOME/.config}/keybinds.txt"
[ -r "$FILE" ] || exit 0
rofi -dmenu -i -p 'USER MANUAL' -theme tron <"$FILE" >/dev/null
