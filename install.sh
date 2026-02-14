#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR..."

# --- Prerequisites ---

if ! command -v claude &>/dev/null; then
    echo "Error: claude CLI not found. Install it first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if ! command -v nvim &>/dev/null; then
    echo "Error: neovim not found. Install v10+: https://github.com/neovim/neovim/releases"
    exit 1
fi

nvim_version=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
if [ "$(echo "$nvim_version < 10.0" | bc)" -eq 1 ]; then
    echo "Error: neovim v10+ required (found v$nvim_version)"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    echo "Error: npm not found. Required for pyright LSP. Install Node.js: https://nodejs.org"
    exit 1
fi

# --- Symlink helper ---

link_file() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local backup="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  Backing up $dst -> $backup"
        mv "$dst" "$backup"
    fi

    ln -sf "$src" "$dst"
    echo "  Linked $src -> $dst"
}

# --- Claude Code ---

echo ""
echo "Setting up Claude Code..."
mkdir -p ~/.claude

link_file "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh

# --- Neovim ---

echo ""
echo "Setting up Neovim..."
mkdir -p ~/.config

link_file "$DOTFILES_DIR/nvim" ~/.config/nvim

# --- tmux ---

echo ""
echo "Setting up tmux..."
link_file "$DOTFILES_DIR/.tmux.conf" ~/.tmux.conf

# --- Claude Code plugins: uninstall removed ---

echo ""
echo "Removing old plugins..."

removed_plugins=(
    "superpowers@superpowers-marketplace"
    "greptile@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
)

installed_plugins_file="$HOME/.claude/plugins/installed_plugins.json"
for plugin in "${removed_plugins[@]}"; do
    if [ -f "$installed_plugins_file" ] && jq -e ".plugins[\"$plugin\"]" "$installed_plugins_file" >/dev/null 2>&1; then
        echo "  Uninstalling $plugin..."
        claude plugin uninstall "$plugin"
    else
        echo "  Skipping $plugin (not installed)"
    fi
done

# --- Claude Code plugins: install ---

echo ""
echo "Installing Claude Code plugins..."

plugins=(
    superpowers
    rust-analyzer-lsp
    pyright-lsp
    code-review
    pr-review-toolkit
    code-simplifier
    frontend-design
    security-guidance
    claude-md-management
    firecrawl
    context7
    explanatory-output-style
)

for plugin in "${plugins[@]}"; do
    echo "  Installing $plugin..."
    claude plugin install "$plugin@claude-plugins-official"
done

# --- Formatters ---

echo ""
echo "Installing formatters..."

echo "  Installing black and isort..."
pip install black isort

echo "  Installing prettier..."
npm install -g prettier

# --- Claude Code settings (after plugins so installs don't override our config) ---

echo ""
echo "Applying Claude Code settings..."
link_file "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json

# --- Summary ---

echo ""
echo "Done! Installed:"
echo ""
echo "  Claude Code:"
echo "    - Settings with coding style, permissions, and formatting hooks"
echo "    - Custom statusline (progress bar, tokens, git branch, project name)"
echo "    - ${#plugins[@]} plugins (${#removed_plugins[@]} old plugins removed)"
echo ""
echo "  Neovim:"
echo "    - Lua config with Lazy.nvim, LSP, treesitter"
echo ""
echo "  tmux:"
echo "    - Custom bindings (prefix: C-a), vim navigation"
echo ""
echo "  Formatters:"
echo "    - black, isort (Python)"
echo "    - prettier (TypeScript/JavaScript)"
echo "    - cargo fmt (install Rust separately if needed)"
