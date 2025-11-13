#!/bin/bash

# Dotfiles installation script
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Installing dotfiles from $DOTFILES_DIR..."

# Create Claude Code config directory if it doesn't exist
echo "📁 Creating Claude Code config directory..."
mkdir -p ~/.claude

# Backup existing Claude Code settings if they exist
if [[ -f ~/.claude/settings.json ]]; then
    echo "💾 Backing up existing Claude Code settings..."
    mv ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# Symlink Claude Code settings
echo "🔗 Linking Claude Code settings..."
ln -sf "$DOTFILES_DIR/claude/settings.json" ~/.claude/settings.json

# Create Neovim config directory if it doesn't exist
echo "📁 Creating Neovim config directory..."
mkdir -p ~/.config

# Backup existing Neovim config if it exists
if [[ -d ~/.config/nvim ]]; then
    echo "💾 Backing up existing Neovim config..."
    mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d_%H%M%S)
fi

# Symlink Neovim config
echo "🔗 Linking Neovim config..."
ln -sf "$DOTFILES_DIR/nvim" ~/.config/nvim

# Backup existing tmux config if it exists
if [[ -f ~/.tmux.conf ]]; then
    echo "💾 Backing up existing tmux config..."
    mv ~/.tmux.conf ~/.tmux.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Symlink tmux config
echo "🔗 Linking tmux config..."
ln -sf "$DOTFILES_DIR/.tmux.conf" ~/.tmux.conf

echo "✅ Dotfiles installation complete!"
echo ""
echo "Configurations installed:"
echo "  🤖 Claude Code:"
echo "    • File reading/searching permissions with security protections"
echo "    • Web search and fetch capabilities"
echo "    • Automatic code formatting for Python, Rust, and TypeScript"
echo "    • Custom coding style preferences (SOLID, elegant code, minimal comments, strict typing)"
echo "    • Error handling preferences (avoid try/except unless necessary)"
echo ""
echo "  ⚡ Neovim:"
echo "    • Complete Lua-based configuration"
echo "    • Plugin management via Lazy.nvim"
echo "    • LSP, treesitter, and modern editing features"
echo ""
echo "  🖥️  tmux:"
echo "    • Custom key bindings (prefix: C-a)"
echo "    • Vim-like pane navigation"
echo "    • Smart vim/tmux pane switching"
echo "    • Enhanced copy/paste with system integration"
echo ""
echo "Required formatters:"
echo "  • Python: black, isort (pip install black isort)"
echo "  • Rust: cargo fmt (included with Rust)"
echo "  • TypeScript/JavaScript: prettier (npm install -g prettier)"