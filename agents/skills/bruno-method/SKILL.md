---
name: bruno-method
description: Use when starting non-trivial engineering work, planning a multi-step change, reviewing a plan or PR for soundness, or about to claim a system "works" / "is fixed" / "is done" without reconciling against serving state. Also fires when the user mentions "Bruno Method", "Five Moves", "falsifier", "evidence bar", "confabulation", "issue train", "serving state", or "distance to the method".
---

# The Bruno Method

## Overview

The LLM is a **non-deterministic compiler**: source language is English, target is running software. The compiler is useful; the *guarantees come from the discipline around it*. This skill is that discipline.

Full text of the specification: see `SPEC.md` next to this file. Read it when a section here is too compressed.

## The Six Axioms

1. **A1** — The compiler is non-deterministic. Permanent property.
2. **A2** — Confabulation = type error. Refuse to advance until resolved.
3. **A3** — Every state transition appends to the trail. Monotonic, immutable.
4. **A4** — The method names what would prove it wrong (it falsifies itself).
5. **A5** — The linker (review) is adversarial. Try to break the build.
6. **A6** — Serving state is truth — not chat, not the agent's conclusion, not the last log line.

## The Five Moves (mandatory, in order)

| Move | Pre | Post | Refusal mode |
|------|-----|------|---------------|
| 1. **Evidence Before Architecture** | Goal/scope/target captured | Snapshot of what *is*: current behavior, recent changes, owner notes, known incidents | Architectural decisions made first are unsound — roll back |
| 2. **Strategy Before Plan** | Move 1 done | Major decisions + an explicit **assumption ledger** (for it to work, what must be true? for it to fail?) | Task lists generated before strategy are precise nonsense |
| 3. **Issues As Memory** | Strategy committed | Parent + child issues with scope, acceptance, owner, falsifier | Work that lives only in chat does not exist |
| 4. **Falsification Before Confidence** | Children defined | Each child has an explicit **falsifier** — a check that retracts the work if reality violates it | Children without falsifiers are not buildable |
| 5. **Closure Against Reality** | Implementation landed | Acceptance reconciled against landed/serving state, evidence linked | "Done" without reconciliation is a lie |

## Plan Strength

```
"this should work"                                    → Weak
"this should work unless A_1, ..., A_n fail"          → Strong
"experiment E will tell us whether A_1..A_n hold"     → Bruno   ← only this passes the optimizer
```

A falsifier is *not* the test. It is the commitment about reality that retracts the work when reality violates it. Examples:
- "If the new query returns more than 1.5× the old latency, retract."
- "If the migration touches more than the listed tables, retract."
- "If the audit log shows access from outside the scoped principals, retract."

## The Evidence Bar (the floor)

```
"works on my machine"   ⊑   linked test run
"I checked it"          ⊑   repro command
"looks fixed"           ⊑   RCA + regression
"demo passed"           ⊑   gate evidence
"merged"                ⊑   landed-state reconciled
```

Bring evidence at-or-above the floor. Below is a type error.

## The Root Rule

> **Assume you are confabulating.**
> **Check facts.**
> **Then check the facts that would prove you wrong.**

Skip clause three and you are type-blind.

## Anti-Patterns (Type Errors — these do not compile)

| Anti-pattern | Why it fails |
|---|---|
| "Use an agent" | No goal, no scope, no target |
| "Make it work" | No acceptance |
| "Demo passed" | Link-time short-circuit |
| "Merged" | Linker bypassed reality |
| "It works on my machine" | Below evidence floor |
| "I checked it" | Unverifiable |
| "We'll test it later" | No falsifier |
| "The agent says it's done" | Serving state not consulted |
| "Trust the model" | Discipline corollary inverted |

## Distance to the Method (self-check)

Rate yourself on each axis from {weak, partial, solid, strong}:

1. **falsifiesPlans** — do you name what would prove the plan wrong?
2. **findsRootCause** — RCA before fix?
3. **leavesTrail** — does the issue/PR carry the memory?
4. **gatesClaims** — does evidence meet the floor before you claim?
5. **slicesWork** — children bounded, parent coordinates only?
6. **reviewsHard** — do you try to break the build?

> On which axis do you most often skip? That's the next thing to harden.

## How to apply this in a session

**Before any non-trivial implementation**:
- Capture Move 1 evidence (current behavior, recent changes, constraints) — read code/logs first, claim later
- Write the assumption ledger explicitly: "for this to work, X, Y, Z must be true"
- State at least one falsifier the work would retract on
- Only then plan tasks

**Before any "done" / "fixed" / "works" / "should be ok" claim**:
- Reconcile against serving state — run the test, query the system, hit the endpoint, check the deploy
- Don't infer success from your own conclusion or the absence of an error
- If you cannot reconcile, say so explicitly instead of claiming closure

**When reviewing a plan or PR**:
- Take the adversarial role (A5)
- For every claim, ask "what would prove this wrong?" and try the check
- Reject merges where the falsifier was not run, the RCA pre-dates the change, or the claim is below the evidence floor

**When uncertain whether a memory / past conclusion / cached fact is current**:
- It might be a confabulation. Check (A2). Then check what would prove it wrong (Root Rule).

## Red Flags — STOP

- About to write code without naming a falsifier → stop, name one
- About to say "should work" / "looks good" / "fixed" without running the check → stop, run the check
- About to mark a task done because the agent said so → stop, consult serving state
- A plan with zero assumptions listed → it has assumptions, you just haven't named them
