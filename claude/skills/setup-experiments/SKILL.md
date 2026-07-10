---
name: setup-experiments
description: Configure a repo for the experiment skills — record its experiment log, primary metric, current champion, launch commands, and config system. Run once per repo before using /experiment.
disable-model-invocation: true
---

# Setup Experiments

Record how *this* repo runs experiments, so `/experiment` plugs into the conventions already here instead of inventing new ones. Every repo tracks experiments differently — this is where those differences get written down.

Prompt-driven, not a script. Explore, present what you found, confirm, then write.

## 1. Explore

Read the repo; don't assume. Find:

- **Config system** — how one experiment is parameterized (a `configs/` or `experiments/` dir, Hydra, argparse, one YAML per run). Grab an example path.
- **Launch commands** — the exact train and eval entry points, with flags.
- **Experiment log** — an existing hand-maintained record (`EXPERIMENTS_LOG.md`, a research log, a results table). This is the lab notebook `/experiment` appends to.
- **Primary metric** — the number that decides win/loss, and how significance is judged (a CI, a bootstrap, seed variance).
- **Champion** — the current best config/run to beat.
- **Run outputs** — where checkpoints, metrics, and logs land.
- **Reproducibility** — seed handling, config snapshotting, data versioning.

## 2. Present and confirm

Summarise what's present and what's missing. Walk the decisions **one at a time** — propose what you found as the default, let the user correct each before moving on:

- **Experiment log** — path to append findings to. If none exists, propose `EXPERIMENTS_LOG.md` at the repo root.
- **Primary metric + significance rule** — e.g. "chunk-99 minADE6@6.4s, paired-bootstrap CI".
- **Champion** — the config/run to beat right now.
- **Launch commands** — train and eval, verbatim.
- **Config system** — how `/experiment` changes exactly one lever versus the champion.

## 3. Write

Write `docs/agents/experiments.md` with the confirmed answers (create `docs/agents/` if absent). Add an `## Experiments` block to the repo's `CLAUDE.md` (or `AGENTS.md` if that's what exists) pointing at it:

```markdown
## Experiments

Experiment discipline is configured in `docs/agents/experiments.md` — log, primary metric, champion, and launch commands read by `/experiment`.
```

If the block already exists, update it in place. Don't touch surrounding sections.

## 4. Done

Tell the user setup is complete and that `/experiment` now reads `docs/agents/experiments.md`. They can edit that file directly; re-run this skill only to reconfigure.
