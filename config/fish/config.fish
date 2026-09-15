# ============================================================================
# tron-grid-dots — fish. Palette colors come from colors.gen.fish (generated).
# ============================================================================

fish_add_path -g ~/.local/bin ~/.cargo/bin

# generated palette (fish syntax colors + $TRON_ACCENT for scripts)
if test -f ~/.config/fish/colors.gen.fish
    source ~/.config/fish/colors.gen.fish
end

if status is-interactive
    # starship prompt (~10 MB, spawned per prompt — fast enough on N4000)
    if command -q starship
        starship init fish | source
    end

    # one Grid line instead of the default fish greeting (cheap: reads a file)
    set -g fish_greeting ""
    if command -q tron
        tron quote
    end

    # aliases
    alias ll  "ls -lah --color=auto"
    alias la  "ls -A --color=auto"
    alias g   git
    alias lg  lazygit
    alias v   nvim
    alias ff  fastfetch
    alias r   ranger
    alias top btop
    alias update tron-update
    alias disc "nvim ~/GRID/disc.md"

    # uncomment for a fetch on every new terminal (costs ~150ms on the N4000)
    # fastfetch
end
