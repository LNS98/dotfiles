#!/bin/bash
# Native plugins and herdr integration have no shared skills responsibility.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v claude >/dev/null 2>&1; then
    echo "Claude CLI absent; skipping native Claude plugins. Shared skills are installed."
    exit 0
fi
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
)

desired_ids=()
for plugin in "${plugins[@]}"; do
    desired_ids+=("$plugin@$marketplace")
done

installed_plugins_file="$HOME/.claude/plugins/installed_plugins.json"

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

# --- Claude Code settings (after plugins so installs don't override our config) ---

echo ""
echo "Applying Claude Code settings..."
# The plugin CLI may have written a fresh settings.json while ours was detached.
# The repo file is the source of truth, so discard it rather than back it up.
if [ "$settings_was_linked" = true ] && [ -f "$settings_file" ] && [ ! -L "$settings_file" ]; then
    rm -f "$settings_file"
fi
if [ -e "$settings_file" ] && [ ! -L "$settings_file" ]; then
    mv "$settings_file" "${settings_file}.backup.$(date +%Y%m%d_%H%M%S)"
fi
ln -sfn "$DOTFILES_DIR/claude/settings.json" "$settings_file"
