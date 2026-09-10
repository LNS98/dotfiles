# Dotfiles

Personal editor, terminal and coding-agent setup. Claude Code and Codex share
instructions and a pinned catalog of 32 skills. Native settings stay separate.

## Install agent configuration

Requires Python 3.12+ and Git. The first installation downloads the pinned sources
from GitHub. Neither agent CLI is required to install instructions and skills.

```sh
./install.sh --agents-only           # Claude Code and Codex
./install.sh --agents-only claude    # Claude Code only
./install.sh --agents-only codex     # Codex only
./install.sh --agents-only --dry-run # Preview, using already downloaded sources
```

For a fresh checkout, download sources before previewing:

```sh
python3 scripts/sync-skills.py
./install.sh --agents-only --dry-run
```

Existing destination files and conflicting symlinks are archived under
`~/.local/share/dotfiles/backups/`. Unrelated skills are preserved. Rerunning
without changes leaves existing links alone. Existing Codex `config.toml` is
preserved; `codex/config.toml` is a starter copied only when no config exists.
`CODEX_HOME` is respected for Codex instructions and native configuration.
User skills still go in `~/.agents/skills`, as specified by Codex.

Start fresh agent sessions after migration to reload global instructions.
In Claude, invoke `/ask-matt`. In Codex, invoke `$ask-matt`.

## One source for both agents

| Source in this repo | Claude Code destination | Codex destination |
| --- | --- | --- |
| `agents/AGENTS.md` | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| `agents/skills/<name>` | `~/.claude/skills/<name>` | `~/.agents/skills/<name>` |
| Pinned skills in `agents/.shared/` | `~/.claude/skills/<name>` | `~/.agents/skills/<name>` |
| `claude/settings.json`, status line | `~/.claude/` | Not applicable |
| `codex/config.toml` | Not applicable | Copy on first install |

Both agents' skill links resolve to the same directories, including references
and supporting scripts. The legacy `claude/skills` and `claude/CLAUDE.md` repo
paths are compatibility symlinks. Edit the files under `agents/`.

The shared catalog contains:

- Five personal skills: `bruno-method`, `experiment`, `experiment-method`,
  `setup-experiments`, `socratic-read`.
- The 25 skills exported by Matt Pocock's v1.2.3 plugin, pinned to its installed
  Git revision. In-progress and miscellaneous skills outside that export stay
  out of the catalog.
- `unslop` and `technical-writing` from Cursor's pstack collection, pinned to
  the previously installed revision.

`agents/sources.json` records source URLs, full commit SHAs and selected paths.
`sync-skills.py` fetches independent checkouts into ignored `agents/.vendor/`.
It exports committed Git content to ignored `agents/.shared/`, omitting plugin manifests
so both agents use the same unprefixed skill names. It does not depend on
Claude's plugin cache or either tool's package manager.
Upstream licenses and references stay with those complete checkouts. Existing
pins are reused, so reruns do not silently upgrade skills. Each sync rebuilds
from the pinned commit and current overlays; deleted overlays disappear and
modified generated files are repaired. Unchanged exports keep their existing
directories. Treat `.shared/` as generated output and edit owned skills or
overlays instead.

`agents/overlays/` contains compatibility metadata only. The pstack overlay maps
`technical-writing`'s existing explicit-only policy to Codex. Matt Pocock already
ships Codex metadata; the personal explicit-only skills also have it. The
installer rejects mismatches before writing links.

To update an upstream source, choose a commit in `agents/sources.json`, review
its skills and invocation metadata, run `sync-skills.py`, then reinstall both
targets. Old checkouts remain available for rollback. Removing a skill from the catalog retires only unchanged links recorded in the
previous installation manifest. User replacements and unrelated skills survive.

## Parity and tool-specific behavior

The 1:1 contract covers the managed skill files, versions, invocation policies,
and shared personal instructions. Models, permissions, hook APIs, LSP plugins,
status lines, voice settings and session controls remain native to each tool.
Shared prose is not equivalent to sandbox enforcement. The shared formatting
instruction gives Codex the same formatter defaults; it is not a port of Claude's
PostToolUse hook. Agent-only installation does not install formatter binaries.

Claude's Matt Pocock plugin is disabled in the tracked user settings to avoid
loading the shared skills twice. Its cache stays intact. A project that explicitly
enables that plugin can override the user setting and cause duplicates; remove
that project override when migrating that project. This machine has a separate
project-scoped installation in `~/Projects/brain`; this migration does not edit
that project's settings.

Project-specific instructions and research workflows remain in their own repos.
Codex's starter config recognizes `CLAUDE.md` as a fallback when `AGENTS.md` is
absent. Existing Codex configs are not rewritten to add that option. New shared
project conventions should use `AGENTS.md`, with `CLAUDE.md` pointing to it.
A Codex `AGENTS.override.md` takes precedence over the shared global file.

## Full workstation setup

```sh
./install.sh
```

This also configures Neovim, tmux and herdr, installs formatters, and runs the
Claude-native plugin adapter when the Claude CLI is available. The adapter keeps
Rust/Python LSP and security-guidance plugins; it does not uninstall unrelated
plugins. The full setup retains its Neovim, npm and jq prerequisites. Use
`--agents-only` on a machine that only needs coding-agent configuration.

Claude settings are symlinked as before. Claude can write machine-local
`autoMode` data into that file. A required Python Git clean filter strips
that field at staging time. Every Claude installation path configures the filter
before linking live settings, including agent-only and direct Python installs. Do not commit
machine-local security context. Codex credentials, project trust and model
choices stay outside this repo.

## Verify

```sh
python3 -m unittest discover -s tests -v
bash -n install.sh
bash -n scripts/install-claude.sh
python3 scripts/sync-skills.py
python3 scripts/install-agents.py --home /tmp/dotfiles-preview --dry-run
```

The unit tests use temporary directories and require no network or agent CLI.
They cover source identity, reruns, backups, target selection, custom Codex home,
missing sources, invocation policy mismatches and obsolete owned links.

Discovery conventions: [Codex skills](https://learn.chatgpt.com/docs/build-skills)
and [Codex global instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
