# Claude Code Setup Cleanup - Design Document

## Goal

A single `install.sh` command that sets up a clean, portable Claude Code configuration from scratch. Public-safe (no secrets), works on any macOS/Linux system with Claude Code installed.

## Repository Structure

```
dotfiles/
├── claude/
│   ├── settings.json          # Main config (symlinked to ~/.claude/settings.json)
│   └── statusline-command.sh  # Statusline script (symlinked to ~/.claude/)
├── nvim/                      # Existing neovim config
├── .tmux.conf                 # Existing tmux config
└── install.sh                 # Full setup script
```

## Plugin Configuration

### Active Plugins (11)

| Plugin | Purpose |
|--------|---------|
| superpowers@claude-plugins-official | Core skills: brainstorming, TDD, debugging, planning, git worktrees |
| rust-analyzer-lsp@claude-plugins-official | Rust LSP code intelligence |
| pyright-lsp@claude-plugins-official | Python LSP code intelligence |
| code-review@claude-plugins-official | Quick `/code-review` command |
| pr-review-toolkit@claude-plugins-official | Deep multi-agent PR reviews |
| code-simplifier@claude-plugins-official | Code cleanup agent |
| frontend-design@claude-plugins-official | UI/UX implementation skill |
| security-guidance@claude-plugins-official | Silent security checks on edits |
| claude-md-management@claude-plugins-official | CLAUDE.md audit and improvement |
| firecrawl@claude-plugins-official | Web research/scraping (NEW) |
| context7@claude-plugins-official | Up-to-date library docs (NEW) |

### Optional Plugins (disabled by default) (1)

| Plugin | Purpose |
|--------|---------|
| explanatory-output-style@claude-plugins-official | Educational insight blocks in output |

### Removed Plugins (3)

| Plugin | Reason |
|--------|--------|
| superpowers@superpowers-marketplace | Duplicate of official version (v4.0.3 vs v4.3.0) |
| greptile@claude-plugins-official | External service dependency, never used |
| ralph-loop@claude-plugins-official | Never used |

## Settings.json Changes

### Hooks

**Keep:** `PostToolUse` hook - formats files after Edit/Write (black, isort, cargo fmt, prettier).

**Remove:** `UserPromptSubmit` hook - redundant with PostToolUse, slow (runs all formatters on all files every prompt), causes unexpected git changes.

### Error Handling Guideline Update

**Before:**
> Error Handling: Avoid try/except blocks unless absolutely no other option

**After:**
> Error Handling: Fail loudly - avoid try/except blocks unless absolutely necessary. Never silently swallow errors

### Statusline

Path updated to reference the symlinked location in dotfiles rather than a hardcoded absolute path.

### Permissions

No changes - current permissions config is clean (allow read/search/web, deny sensitive files).

## Install Script Behavior

```
1. Check prerequisites
   - Verify `claude` CLI is installed and on PATH

2. Symlink configs (with backup of existing files)
   - claude/settings.json     -> ~/.claude/settings.json
   - claude/statusline-command.sh -> ~/.claude/statusline-command.sh
   - nvim/                    -> ~/.config/nvim
   - .tmux.conf               -> ~/.tmux.conf

3. Uninstall removed plugins
   - superpowers@superpowers-marketplace
   - greptile@claude-plugins-official
   - ralph-loop@claude-plugins-official

4. Install plugins (fail loudly on error)
   - 12 plugins from claude-plugins-official (11 active + 1 optional)

5. Print summary of what was installed
```

No error suppression. Script fails immediately if any step fails.

## What's NOT Included (by design)

- No API keys or tokens
- No per-project CLAUDE.md files (those live in individual project repos)
- No GSD or other conflicting workflow plugins
- No UserPromptSubmit hook
