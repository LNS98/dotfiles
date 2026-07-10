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
if [ "$(echo "$nvim_version < 0.10" | bc)" -eq 1 ]; then
    echo "Error: neovim v0.10+ required (found v$nvim_version)"
    exit 1
fi

if ! command -v npm &>/dev/null; then
    echo "Error: npm not found. Required for pyright LSP. Install Node.js: https://nodejs.org"
    exit 1
fi

# Used to prune stale plugin entries below; without it the cleanup silently no-ops.
if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install it: brew install jq"
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

    # -n: don't follow $dst if it's already a symlink to a directory,
    # otherwise the new link lands *inside* the target dir.
    ln -sfn "$src" "$dst"
    echo "  Linked $src -> $dst"
}

# --- Claude Code ---

echo ""
echo "Setting up Claude Code..."
mkdir -p ~/.claude

link_file "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh
link_file "$DOTFILES_DIR/claude/CLAUDE.md" ~/.claude/CLAUDE.md

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
    "superpowers@claude-plugins-official"
    "firecrawl@claude-plugins-official"
    "context7@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "pr-review-toolkit@claude-plugins-official"
    "code-review@claude-plugins-official"
)

installed_plugins_file="$HOME/.claude/plugins/installed_plugins.json"
for plugin in "${removed_plugins[@]}"; do
    if [ -f "$installed_plugins_file" ] && jq -e ".plugins[\"$plugin\"]" "$installed_plugins_file" >/dev/null 2>&1; then
        echo "  Removing $plugin from installed_plugins.json..."
        tmp=$(jq "del(.plugins[\"$plugin\"])" "$installed_plugins_file")
        echo "$tmp" > "$installed_plugins_file"
    else
        echo "  Skipping $plugin (not installed)"
    fi
done

# Also remove stale entries from enabledPlugins in a *pre-existing* settings.json.
# Skip if it's already our symlink: writing through it would edit the tracked
# repo file, and that file is the source of truth we're about to install anyway.
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
    for plugin in "${removed_plugins[@]}"; do
        if jq -e ".enabledPlugins[\"$plugin\"]" "$settings_file" >/dev/null 2>&1; then
            echo "  Removing $plugin from settings.json enabledPlugins..."
            tmp=$(jq "del(.enabledPlugins[\"$plugin\"])" "$settings_file")
            echo "$tmp" > "$settings_file"
        fi
    done
fi

# --- Claude Code plugins: install ---

echo ""
echo "Installing Claude Code plugins..."

plugins=(
    rust-analyzer-lsp
    pyright-lsp
    security-guidance
)

for plugin in "${plugins[@]}"; do
    echo "  Installing $plugin..."
    claude plugin install "$plugin@claude-plugins-official"
done

# --- Personal skills (owned, symlinked from this repo) ---

echo ""
echo "Linking personal skills..."
mkdir -p ~/.claude/skills

# Backups must live outside ~/.claude/skills, or Claude Code loads them as
# duplicate skills (a backup dir still contains a valid SKILL.md).
SKILL_BACKUP_DIR="$HOME/.claude/skill-backups"

for skill in "$DOTFILES_DIR"/claude/skills/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    target="$HOME/.claude/skills/$name"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$SKILL_BACKUP_DIR"
        backup="$SKILL_BACKUP_DIR/${name}.$(date +%Y%m%d_%H%M%S)"
        echo "  Backing up existing $name -> $backup"
        mv "$target" "$backup"
    fi
    ln -sfn "${skill%/}" "$target"
    echo "  Linked $name"
done

# --- Matt Pocock's skills (tracked upstream; git pull to update) ---

echo ""
echo "Setting up Matt Pocock's skills..."
MP_DIR="$HOME/.claude/vendor/mattpocock-skills"
if [ -d "$MP_DIR/.git" ]; then
    git -C "$MP_DIR" pull --quiet && echo "  Updated existing clone"
else
    mkdir -p "$HOME/.claude/vendor"
    git clone --quiet https://github.com/mattpocock/skills.git "$MP_DIR" && echo "  Cloned"
fi
# Link only the promoted skills (engineering + productivity), skipping his personal/in-progress ones
for d in "$MP_DIR"/skills/engineering/*/ "$MP_DIR"/skills/productivity/*/; do
    [ -f "$d/SKILL.md" ] || continue
    ln -sfn "${d%/}" "$HOME/.claude/skills/$(basename "$d")"
done
# resolving-merge-conflicts sits in his engineering folder but isn't in his promoted set
rm -f "$HOME/.claude/skills/resolving-merge-conflicts"
echo "  Linked promoted skills; update anytime with: git -C \"$MP_DIR\" pull"

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
