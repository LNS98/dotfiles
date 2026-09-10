# Agent compatibility checks

File parity establishes that both hosts read the same instructions. Workflow
checks establish whether each host follows those instructions with its own tools.
Run both when changing skill selection, patches, invocation policy or host versions.

## Installer checks

Run the offline tests and shell checks listed in README.md. The settings tests
verify that model choices, permissions, hooks and unrelated plugins remain active,
that external settings targets are preserved, and that native plugin failures
restore this checkout's live settings link.

For a real upstream install, use a new temporary destination:

```sh
python3 scripts/install-agents.py --home /tmp/dotfiles-preview
```

Check all 32 names from `agents/sources.json` and `agents/skills/`: each
`.claude/skills/<name>` and `.agents/skills/<name>` must resolve to the same
folder. Check each explicit-only skill's Claude frontmatter and Codex metadata.
Check that `setup-matt-pocock-skills/SKILL.md` contains the replacement from
`agents/patches.json`. Repeat the installation and these checks to test reruns.

The upstream CLI reinstalls the pinned original before the wrapper reapplies
its patch. A changed patch anchor must stop installation with an error; review
and update the patch before accepting a new upstream revision.

## Workflow checks

Use a disposable Git repo with two small Python modules and a short local article.
Create real `.agents/skills` and `.claude/skills` directories in the fixture and
link each preview skill into them individually, matching the installer's layout.
Copy `agents/AGENTS.md` into the fixture's `AGENTS.md`. Use the host's
normal permission enforcement and disable unrelated hooks and external services.
Keep each transcript and inspect actual tool calls and resulting files.

| Check | Prompt and expected evidence |
| --- | --- |
| Project setup | Invoke `/setup-matt-pocock-skills` in Claude or `$setup-matt-pocock-skills` in Codex. Request a draft and stop before approval. The draft puts shared guidance in `AGENTS.md` and makes it reachable from `CLAUDE.md`. No files change before approval. |
| Approved setup | In a disposable fixture, approve a concrete draft. Check the resulting shared block and Claude import, preservation of unrelated instructions, and a rerun without duplicate blocks or imports. |
| Delegation | Invoke `improve-codebase-architecture` explicitly and assign two workers one module each. Inspect actual delegation calls and worker results. Sequential work is a reported limitation if the host has no delegation tools. |
| Explicit-only invocation | Invoke `socratic-read` explicitly against the local article. It reads the article, asks the first question, and waits without supplying a summary. |
| Implicit exclusion | In a fresh session, request a one-sentence factual explanation from that article without naming `socratic-read`. It answers directly without invoking the explicit-only skill or starting a teaching exercise. |

Repeat the setup cases with neither instruction file, only `AGENTS.md`, only
`CLAUDE.md`, both as separate files, and `CLAUDE.md` symlinked to `AGENTS.md`.
Separate Claude files use `@AGENTS.md`; a shared symlink needs no import. Include
an older Agent skills block in a separate Claude file to verify its approved
migration preserves user edits. Never add an import from a file to itself.

Record host versions and whether each check passed, failed or could not run.
A passing discovery check does not substitute for an unavailable workflow test.

Claude imports are documented in [Claude memory](https://code.claude.com/docs/en/memory).
Codex's one-file-per-directory rule is documented in
[AGENTS.md discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
