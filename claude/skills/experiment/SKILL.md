---
name: experiment
description: Run one ML experiment as a disciplined loop — from a vague "improve the model" to a logged keep/kill decision. Reads the repo's experiment config; you hold the gates, the agent does the legwork.
disable-model-invocation: true
argument-hint: "the goal or hypothesis you're chasing"
---

# Experiment

Drive one turn of the experiment loop. You bring a goal — even a vague one ("find a new way to improve the model"); this sharpens it into a falsifiable hypothesis, tests it against the champion by moving exactly one lever, and records the finding.

Read `docs/agents/experiments.md` for this repo's log, metric, champion, and launch commands — run `/setup-experiments` if it's missing.

The discipline lives in the `/experiment-method` reference — consult it. Use `/grilling` for every decision that's yours to put to the user, and `/research` first when the idea needs grounding in literature.

## The loop

Walk these in order. **The user approves at each gate; never run past a rejected gate.**

1. **Become one with the data.** Before proposing anything, surface where the champion fails now — the slices with the worst metric, concrete failing cases. Ground ideas in evidence, not vibes. Present what you find.
2. **Frame hypotheses.** Turn the goal into 3–5 *ranked, falsifiable* hypotheses (via `/grilling`), each naming the lever, its predicted effect on the primary metric, and why. The user picks one — or redirects.
3. **Design the minimal experiment.** The smallest change that tests the chosen hypothesis: **one lever versus the champion**, the metric, and the **decision rule written before the run** — what result confirms versus refutes, against the significance bar. De-risk first: overfit a tiny batch to prove the code runs. Snapshot config and seed. Confirm the design.
4. **Run.** Launch via the repo's command — the de-risk check first, then the real run. Report progress; don't editorialize.
5. **Analyze against the prediction.** Compare to the champion *and* to noise — real signal or seed variance, per the significance rule? State the verdict plainly.
6. **Capture and decide.** Append the finding to the experiment log — **win or loss** — with hypothesis, setup, result, and the one-line lesson. Then put **keep / kill / iterate** to the user.

## Completion

Done when the finding is in the log and the user has made the keep/kill/iterate call. A loss fully logged is a complete experiment — a dead lever recorded is a lever no one re-runs.
