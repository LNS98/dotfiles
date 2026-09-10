#!/bin/bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1:-}" = "--help" ]; then
    echo "Usage: ./install.sh [--agents-only [all|claude|codex] [--dry-run]]"
    exit 0
fi
if [ "${1:-}" = "--agents-only" ]; then
    shift
    target="${1:-all}"
    if [ "$target" != "--dry-run" ]; then
        [ "$#" -eq 0 ] || shift
    else
        target=all
    fi
    case "$target" in all|claude|codex) ;; *) echo "Unknown target: $target" >&2; exit 2 ;; esac
    if [ "${1:-}" = "--dry-run" ]; then
        shift
        [ "$#" -eq 0 ] || { echo "Unexpected arguments" >&2; exit 2; }
        exec python3 "$DOTFILES_DIR/scripts/install-agents.py" --target "$target" --dry-run
    fi
    [ "$#" -eq 0 ] || { echo "Unexpected arguments" >&2; exit 2; }
    python3 "$DOTFILES_DIR/scripts/sync-skills.py"
    exec python3 "$DOTFILES_DIR/scripts/install-agents.py" --target "$target"
fi
[ "$#" -eq 0 ] || { echo "Use --help for usage" >&2; exit 2; }

echo "Installing dotfiles from $DOTFILES_DIR..."
if ! command -v nvim &>/dev/null; then
    echo "Error: neovim not found. Install v10+: https://github.com/neovim/neovim/releases"
    exit 1
fi

nvim_version=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+')
if [ "$(echo "$nvim_version < 0.10" | bc)" -eq 1 ]; then
    echo "Error: neovim v0.10+ required (found v$nvim_version)"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    echo "Error: npm not found. Required for pyright LSP. Install Node.js: https://nodejs.org"
    exit 1
fi

# Used by the native Claude plugin installer.
if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install it: brew install jq"
    exit 1
fi

# --- Symlink helper ---

link_file() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local backup
        backup="${dst}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  Backing up $dst -> $backup"
        mv "$dst" "$backup"
    fi

    # -n: don't follow $dst if it's already a symlink to a directory,
    # otherwise the new link lands *inside* the target dir.
    ln -sfn "$src" "$dst"
    echo "  Linked $src -> $dst"
}

# Shared instructions and skills, independent of either agent CLI.
python3 "$DOTFILES_DIR/scripts/sync-skills.py"
python3 "$DOTFILES_DIR/scripts/install-agents.py"

# --- Neovim ---

echo ""
echo "Setting up Neovim..."
mkdir -p ~/.config

link_file "$DOTFILES_DIR/nvim" ~/.config/nvim

# --- tmux ---

echo ""
echo "Setting up tmux..."
link_file "$DOTFILES_DIR/.tmux.conf" ~/.tmux.conf

# --- herdr ---

echo ""
echo "Setting up herdr..."
mkdir -p ~/.config/herdr
link_file "$DOTFILES_DIR/herdr/config.toml" ~/.config/herdr/config.toml
link_file "$DOTFILES_DIR/herdr/status.sh" ~/.config/herdr/status.sh

# Optional: herdr replaces tmux for agent sessions but is not required.
# The config uses 0.8+ keys; older herdr ignores them with warnings and lacks `config check`.
if command -v herdr &>/dev/null; then
    herdr_version="$(herdr --version | awk '{print $2}')"
    if [ "$(printf '%s\n' 0.8.2 "$herdr_version" | sort -V | head -1)" != "0.8.2" ]; then
        echo "  Warning: herdr $herdr_version is older than 0.8.2; detach and run: herdr update --handoff"
    elif herdr config check >/dev/null 2>&1; then
        echo "  herdr $herdr_version config ok"
    else
        echo "  Warning: herdr config check failed:"
        herdr config check 2>&1 | sed 's/^/    /' || true
    fi
    # A running server keeps the old config until told to reload; quiet no-op if not running.
    herdr server reload-config >/dev/null 2>&1 || true
else
    # The direct installer is what `herdr update --handoff` (live-preserving updates) supports;
    # brew/mise/nix installs update through their package manager and lose running panes.
    echo "  herdr not installed (optional): curl -fsSL https://herdr.dev/install.sh | sh"
fi

bash "$DOTFILES_DIR/scripts/install-claude.sh"

# --- Formatters ---

echo ""
echo "Installing formatters..."

# Homebrew python is PEP 668 externally-managed, so `pip install` is refused.
# Prefer brew, fall back to pipx; never touch the system interpreter.
install_python_tool() {
    local tool="$1"
    if command -v "$tool" &>/dev/null; then
        echo "  $tool already present ($(command -v "$tool"))"
    elif command -v brew &>/dev/null; then
        echo "  Installing $tool via brew..."
        brew install "$tool"
    elif command -v pipx &>/dev/null; then
        echo "  Installing $tool via pipx..."
        pipx install "$tool"
    else
        echo "Error: need brew or pipx to install $tool (pip is externally-managed)."
        exit 1
    fi
}

install_python_tool black
install_python_tool isort

if command -v prettier &>/dev/null; then
    echo "  prettier already present ($(command -v prettier))"
else
    echo "  Installing prettier..."
    npm install -g prettier
fi

echo "Done: shared Claude/Codex skills, Neovim, tmux, herdr and formatters."
