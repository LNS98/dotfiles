#!/bin/bash
# Native plugins and herdr integration have no shared skills responsibility.
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v claude >/dev/null 2>&1; then
    echo "Claude CLI absent; skipping native Claude plugins. Shared skills are installed."
    exit 0
fi
# Preserve local settings. Only detach this checkout's live settings link;
# native CLI writes must not change the tracked defaults.
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings_file="$claude_dir/settings.json"
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
    settings_copy="$(mktemp "$claude_dir/settings.XXXXXX")"
    cp "$settings_file" "$settings_copy"
    if [ "$settings_file" -ef "$DOTFILES_DIR/claude/settings.json" ]; then
        settings_was_linked=true
    fi
    rm "$settings_file"
    mv "$settings_copy" "$settings_file"
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

installed_plugins_file="$claude_dir/plugins/installed_plugins.json"

# --- Claude Code plugins: install ---

echo ""
echo "Installing Claude Code plugins..."

# Check the install manifest before asking the CLI to install a plugin again.
for plugin in "${desired_ids[@]}"; do
    if [ -f "$installed_plugins_file" ] &&
       jq -e --arg p "$plugin" '.plugins[$p]' "$installed_plugins_file" >/dev/null 2>&1; then
        echo "  $plugin already installed"
        continue
    fi
    echo "  Installing $plugin..."
    claude plugin install "$plugin" </dev/null
done

# The EXIT trap restores only this checkout's original link. Local settings
# retain both their existing preferences and the native CLI's plugin additions.
