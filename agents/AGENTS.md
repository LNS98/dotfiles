# Global preferences

Apply the `unslop` skill to everything you write for me: replies, commit messages, PR descriptions, docs. Lead with the conclusion.

## Shared skills

Claude Code and Codex use the same personal skills and pinned upstream sources.
When a workflow says `/name`, use that named skill: Claude exposes `/name`,
Codex exposes `$name`. Read its SKILL.md and required references. Respect its
invocation policy and user checkpoints. Use the host's available tools for the
same operation; do not assume Claude-specific tools or hooks exist in Codex.
When a workflow requests subagents, use the host's delegation tools and pass
each worker a bounded task. If delegation is unavailable, report that limitation
and perform the work sequentially. A worker already assigned a bounded task
performs it directly instead of delegating the same task again.
Project AGENTS.md instructions take precedence over these personal defaults.

After code edits, run the project's formatter for the files changed. Follow the
project's conventions first; the personal defaults are black and isort for
Python, cargo fmt for Rust, and prettier for JavaScript and TypeScript.
This instruction does not provide sandbox enforcement or permission to bypass
host approval settings.
