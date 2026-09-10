# Dotfiles

Personal editor, terminal and coding-agent setup. Claude Code and Codex share
personal instructions and the same selection of 32 skills. Native settings stay
separate.

## Install agent configuration

Requires Python 3, Git and npm/npx. Neither agent CLI is required.

```sh
./install.sh --agents-only
./install.sh --agents-only claude
./install.sh --agents-only codex
./install.sh --agents-only --dry-run
```

The installer calls Matt Pocock's recommended `skills` CLI for third-party
skills. `agents/sources.json` selects the CLI version, repository revisions and
skill names. Each source is installed with the equivalent of:

```sh
npx --yes --package=node@22 --package=skills@1.5.25 -- skills add \
  'https://github.com/mattpocock/skills.git#<revision>' \
  --global --agent claude-code codex --skill <selected-names> --yes
```

npm supplies a temporary Node 22 runtime because this CLI release requires
Node 22.20+. This does not change the shell's default Node installation. npm
running under an older Node can print an engine warning during package download;
the command itself runs under the supplied Node 22 runtime.

Upstream owns fetching, installing, symlinking and its lockfile. Dotfiles does
not clone upstream repositories or generate exports. Its wrapper backs up
existing selected skill destinations before invoking the CLI, then applies the
compatibility metadata in `agents/overlays/` and the reviewed text replacement
in `agents/patches.json`. A patch fails if the pinned source text has changed;
review it when advancing the upstream revision. Upstream installation
failures stop the setup; backups remain available if a command partly installed
its skills.

Dry runs print commands and proposed links without downloading or writing.
Reruns reinstall the selected upstream versions using the CLI. Personal links
and existing native Codex config are left alone when already correct.

Start fresh agent sessions to reload global instructions. Invoke `/ask-matt` in
Claude or `$ask-matt` in Codex.

## Shared files

| Source | Claude Code | Codex |
| --- | --- | --- |
| `agents/AGENTS.md` | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` |
| `agents/skills/<name>` | Symlink in `~/.claude/skills/` | Symlink in `~/.agents/skills/` |
| Third-party skills installed by `skills` | Symlink in `~/.claude/skills/` | Canonical directory in `~/.agents/skills/` |
| `claude/settings.json` | Symlink on first install; existing settings preserved | Not applicable |
| Claude status line | Symlink in `~/.claude/` | Not applicable |
| `codex/config.toml` | Not applicable | Copied only on first install |

Both tools read identical skill files and references. The legacy repo paths
`claude/skills` and `claude/CLAUDE.md` remain compatibility symlinks. Edit personal
files under `agents/`.

The selected catalog contains five personal skills, the 25 promoted skills from
Matt Pocock's v1.2.3 release, and pstack's `unslop` and `technical-writing`.
The pstack overlay preserves `technical-writing`'s existing explicit-only policy
in Codex. The setup skill patch writes shared project guidance to `AGENTS.md`
and makes it reachable from `CLAUDE.md`, preserving the user's approval gate.
Both hosts read the same patched content. Matt Pocock already ships Codex
metadata. Installation checks that the selected skills exist and their
invocation policies agree.

The `skills` CLI maintains its global lockfile under `~/.agents/`. To change an
upstream version or skill selection, edit `agents/sources.json` and rerun the
installer for both tools. Remove unwanted upstream skills with
`npx skills remove --global <name>` and remove their selection from the manifest.
Running `skills update` separately may advance versions beyond the dotfiles pins;
rerunning dotfiles reinstalls the selected pins. Reapply dotfiles after direct
upstream installs or updates to restore the compatibility adjustments.

Personal skill retirement uses the dotfiles installation manifest and removes
only unchanged links it owns. Upstream skills are managed by the upstream CLI.
Old ignored `agents/.vendor/` and `agents/.shared/` directories from the initial
migration are no longer used; they can remain for rollback.

## Existing configuration and parity

Backups are under `~/.local/share/dotfiles/backups/`. Unrelated skills are kept.
Existing Codex `config.toml` is preserved. `CODEX_HOME` is respected for Codex
instructions and native configuration; this CLI's universal Codex skills use
`~/.agents/skills`. An `AGENTS.override.md` takes precedence over shared guidance.

Existing Claude settings retain their model, permissions, hooks and unrelated
plugins. The installer changes only the Matt Pocock plugin's enabled flag and
snapshots the original settings first. A link to another checkout is detached
when that flag needs changing so the other checkout is preserved. An existing
link to this checkout remains live. Invalid settings stop setup before mutation.

Claude's Matt Pocock plugin is disabled to avoid loading the same skills twice.
Its cache stays intact. A project-level plugin setting may enable it again and
cause duplicates; migrate that project's setting separately.

The 1:1 contract covers managed skill content, selected versions, invocation
policies and personal instructions. Models, permission enforcement, hook APIs,
LSP plugins, status lines and session controls remain native. Shared formatting
guidance is not equivalent to Claude's PostToolUse hook or sandbox enforcement.
This setup uses the default `~/.claude` directory. A different
`CLAUDE_CONFIG_DIR` is rejected before changes so the upstream CLI and personal
configuration cannot silently install into different locations.

Updating shared skill content affects every tool linked to it, even if only one
target was selected for installation.

Project workflows remain in their repos. Codex's starter config recognizes
`CLAUDE.md` as a fallback when `AGENTS.md` is absent; existing Codex configs are
not rewritten to add that option.
Project setup uses `AGENTS.md` as the shared source and an `@AGENTS.md` import
in a separate `CLAUDE.md`. An existing `CLAUDE.md` symlink to `AGENTS.md` also
works. The fallback alone cannot share guidance when both files exist separately.

Every Claude setup configures the required Python Git clean filter before
linking live settings. It removes machine-local `autoMode` data at staging time
and makes staging fail if the filter cannot run. Keep credentials and project
trust outside this repo.

## Full workstation setup

```sh
./install.sh
```

This also configures Neovim, tmux and herdr, installs formatters, and runs the
Claude-native plugin adapter when Claude is available. The adapter keeps the
Rust/Python LSP and security-guidance plugins without pruning unrelated plugins.
Full setup also requires Neovim and jq; agent-only setup does not.

## Verify

```sh
python3 -m unittest discover -s tests -v
bash -n install.sh
bash -n scripts/install-claude.sh
./install.sh --agents-only --dry-run
```

Tests use temporary directories and stub the upstream CLI. They cover command
selection, backups, failures, dry runs, personal links and the settings filter.
They also cover active Claude preference preservation, native installer success
and failure, and rejection of upstream patch drift. Discovery and file parity
do not establish identical workflow behavior; use the host checks in
[the compatibility test guide](docs/agent-compatibility.md).
For a real CLI smoke test without replacing global skills:

```sh
python3 scripts/install-agents.py --home /tmp/dotfiles-preview
```

An alternate `--home` uses the upstream CLI's project scope inside that directory,
with isolated CLI state. It simulates the `.agents/skills` and `.claude/skills`
layout; it is not a global install for another account.

Sources: [Matt Pocock installation](https://github.com/mattpocock/skills#installation-30-second-setup),
[skills CLI](https://github.com/vercel-labs/skills),
[Codex skills](https://learn.chatgpt.com/docs/build-skills).
