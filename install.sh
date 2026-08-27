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

# --- Claude Code ---

echo ""
echo "Setting up Claude Code..."
mkdir -p ~/.claude

# settings.json is symlinked into the live ~/.claude, where Claude Code writes
# machine-local security context (autoMode) that must never reach the public
# repo. The stripAutoMode filter (declared in .gitattributes) drops that key at
# git-add time; `required` makes commits fail loudly if the filter is missing.
git -C "$DOTFILES_DIR" config filter.stripAutoMode.clean "jq 'del(.autoMode)'"
git -C "$DOTFILES_DIR" config filter.stripAutoMode.smudge cat
git -C "$DOTFILES_DIR" config filter.stripAutoMode.required true

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

# --- Claude Code plugins: converge to the desired set ---

# `claude plugin` writes to ~/.claude/settings.json. When that path is already
# our symlink, those writes land in the tracked repo — uninstalling an enabled
# plugin would delete its key there. Detach it now; it is relinked at the end.
settings_file="$HOME/.claude/settings.json"
settings_was_linked=false

# If we die between detaching and relinking, the user is left with no settings.
restore_settings_link() {
    if [ "$settings_was_linked" = true ] && [ ! -L "$settings_file" ]; then
        rm -f "$settings_file"
        ln -sfn "$DOTFILES_DIR/claude/settings.json" "$settings_file"
    fi
}
trap restore_settings_link EXIT

if [ -L "$settings_file" ]; then
    rm "$settings_file"
    settings_was_linked=true
fi

# herdr's Claude integration (session ids reported to herdr, so agents resume
# after a server restart) installs a hook script AND appends a SessionStart
# hook with an absolute path to settings.json. Run it here, while settings.json
# is detached, so only the script lands; the tracked settings.json already
# carries a portable $HOME-based version of that hook.
if command -v herdr &>/dev/null; then
    echo ""
    echo "Installing herdr Claude integration..."
    herdr integration install claude </dev/null || echo "  Warning: herdr integration install failed"
fi

marketplace="claude-plugins-official"
plugins=(
    rust-analyzer-lsp
    pyright-lsp
    security-guidance
    mattpocock-skills
)

desired_ids=()
for plugin in "${plugins[@]}"; do
    desired_ids+=("$plugin@$marketplace")
done

echo ""
echo "Removing plugins outside the desired set..."

installed_plugins_file="$HOME/.claude/plugins/installed_plugins.json"
if [ -f "$installed_plugins_file" ]; then
    while read -r installed; do
        [ -n "$installed" ] || continue
        if printf '%s\n' "${desired_ids[@]}" | grep -qxF "$installed"; then
            continue
        fi
        echo "  Uninstalling $installed..."
        claude plugin uninstall "$installed" </dev/null
    done < <(jq -r '.plugins | keys[]' "$installed_plugins_file")
else
    echo "  No plugins installed yet"
fi

# --- Claude Code plugins: install ---

echo ""
echo "Installing Claude Code plugins..."

# With settings.json detached the CLI can't see enabledPlugins, so it would
# re-register every plugin on each run. Check the install manifest instead.
for plugin in "${desired_ids[@]}"; do
    if [ -f "$installed_plugins_file" ] &&
       jq -e --arg p "$plugin" '.plugins[$p]' "$installed_plugins_file" >/dev/null 2>&1; then
        echo "  $plugin already installed"
        continue
    fi
    echo "  Installing $plugin..."
    claude plugin install "$plugin" </dev/null
done

# --- Personal skills (owned, symlinked from this repo) ---

echo ""
echo "Linking personal skills..."
mkdir -p ~/.claude/skills

# Backups must live outside ~/.claude/skills, or Claude Code loads them as
# duplicate skills (a backup dir still contains a valid SKILL.md).
SKILL_BACKUP_DIR="$HOME/.claude/archive/skills"

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

# Matt Pocock's skills ship as a native plugin since their v1.2; they are
# installed by the plugin convergence above (mattpocock-skills in plugins=()).

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
# The plugin CLI may have written a fresh settings.json while ours was detached.
# The repo file is the source of truth, so discard it rather than back it up.
if [ "$settings_was_linked" = true ] && [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
    rm -f "$settings_file"
fi
link_file "$DOTFILES_DIR/claude/settings.json" "$settings_file"

# --- Summary ---

echo ""
echo "Done! Installed:"
echo ""
echo "  Claude Code:"
echo "    - Settings with coding style, permissions, and formatting hooks"
echo "    - Custom statusline (progress bar, tokens, git branch, project name)"
echo "    - ${#plugins[@]} plugins (anything outside the set uninstalled)"
echo ""
echo "  Neovim:"
echo "    - Lua config with Lazy.nvim, LSP, treesitter"
echo ""
echo "  tmux:"
echo "    - Custom bindings (prefix: C-a), vim navigation"
echo ""
echo "  herdr:"
echo "    - tmux-parity bindings (prefix: C-a), tokyo-night theme, bottom status bar"
echo ""
echo "  Formatters:"
echo "    - black, isort (Python)"
echo "    - prettier (TypeScript/JavaScript)"
echo "    - cargo fmt (install Rust separately if needed)"
