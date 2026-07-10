---
name: experiment-method
description: The discipline behind running ML experiments — falsifiable hypotheses, one lever vs the champion, signal vs noise, capture every result. Use when designing or judging an experiment, when the user mentions ablations, baselines, or "did it actually help", or when /experiment needs the method.
---

# Experiment Method

The way to run experiments so each one *teaches* you something. This is the reference the `/experiment` loop leans on; every rule applies on every experiment.

## Champion and challenger

The **champion** is the current best config — the number to beat. Every experiment is a **challenger** that changes **exactly one lever** against it. One lever, so any move in the metric has exactly one cause. Change two and a win tells you nothing about which did it.

## Falsifiable hypotheses

A hypothesis names a lever, a predicted effect, and a metric: *"neighbor attention cuts minADE6 on the interactive slice by ≥5%."* If you can't state the prediction, it's a vibe — sharpen it or drop it. Generate 3–5 ranked before testing one; a single hypothesis anchors you on the first idea that sounded good.

## Become one with the data

Ideas come from failure, not imagination. Before hypothesizing, look at where the champion loses — the worst slices, concrete failing examples. Karpathy's first step, and the most-skipped one.

## Signal vs noise

A number that beat the champion by less than its own variance beat nothing. Judge every result against the repo's significance bar — seed variance, a CI, a bootstrap. Run multiple seeds when the gap is small. Chasing noise is the most common way an experiment lies to you.

## The recipe — greenfield strategy

When bringing up a *new* model or task (not iterating an existing champion), follow Karpathy's order instead of the loop:

1. **Inspect the data** — become one with it before touching code.
2. **Skeleton + dumb baseline** — end-to-end plumbing with the simplest model that runs; get the input pipeline and eval right first.
3. **Overfit one batch** — prove the model *can* learn before asking it to generalize.
4. **Regularize** — only once it overfits.
5. **Tune** — hyperparameters, one region at a time.
6. **Squeeze** — ensembles, longer schedules, the last few points.

Each stage becomes the champion the next one challenges.

## Capture every result

The log is the point. Record **wins and losses alike** — hypothesis, setup, result, one-line lesson — so knowledge compounds and no dead lever is ever re-run. An unlogged experiment is one you will unknowingly repeat.

## Anti-patterns

- **Two levers at once** — a result you can't attribute.
- **No baseline** — a number with nothing to beat.
- **Chasing noise** — a win declared inside the variance band.
- **Skipping the data** — hypotheses from imagination, not failure modes.
- **Logging only wins** — the losses are what stop you repeating them.
