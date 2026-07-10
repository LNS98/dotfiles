# The Bruno Method
## A Formal Specification of Engineering in the Compiler Age

> Companion to the *Bruno Method* deck. The deck tells the story; this document defines the system.
> Working draft. Subject to falsification.

> Source: https://www.olympum.com/bruno-method/SPEC.md

---

## 0. How to read this document

This is a specification for a **compiler system** whose source language is English and whose target is running software. The compiler is the LLM. The discipline around it is the *Bruno Method*.

The shape borrows from compiler references:

1. The compilation model — what compiles what.
2. The source language — what we are willing to call a program.
3. The type system — what we are willing to call a true claim.
4. The intermediate representation — where the program lives between source and binary.
5. The optimization passes — the Five Moves.
6. The debugger — falsification.
7. The linker — adversarial review.
8. The runtime — the agent harness.
9. The build system — the issue graph.
10. Soundness and completeness — what the method does and does not promise.
11. Anti-patterns — programs that refuse to compile.
12. Distance to the method — the metric.

Read it in any order. The deck makes the same argument; this file gives it sharper edges.

---

## 1. The compilation model

### 1.1 The pipeline

```
INTENT (English) ──▶ LLM COMPILER ──▶ AGENT RUNTIME ──▶ SOFTWARE
   │                     │                  │              │
   │                     ▼                  ▼              ▼
   │              non-deterministic    bounded         landed state
   │                 translation       execution       (reality)
   │
   └── shaped by the Bruno Method ◀───────────────────────┘
                                       reconciliation
```

A program in this system is an English description of intent. The compiler is a Large Language Model. It emits a probabilistic candidate artifact graph; the runtime executes it; reality returns observations. The method closes the gap between candidate and reality.

### 1.2 The non-determinism axiom

> **A1.** The LLM compiler is non-deterministic by construction. The same source program may produce different artifacts on different runs. Treat that as a permanent property.

Every other axiom in this document is a consequence of A1.

### 1.3 The discipline corollary

> **C1.** The guarantees come from the *discipline around* the compiler.

The compiler remains useful; the surrounding discipline carries the guarantee.

### 1.4 Comparison to traditional compilers

| Traditional compiler | LLM compiler |
|---|---|
| Deterministic | Non-deterministic |
| Strict grammar | Ambiguous, multi-valent grammar |
| Repeatable output | Persuasive output, not repeatable |
| Errors at compile time | Errors at any time, including after deploy |
| Tested by the compiler authors | Validated by the discipline of the user |

The shift is from a deterministic compiler with known failure modes to a non-deterministic compiler with an unbounded failure surface. Engineering practice has to absorb that change.

---

## 2. The source language: English

### 2.1 Definition

> A **program** in this system is an English description of intent that has, at minimum:
> 1. a **goal** — what should be true after compilation,
> 2. a **scope** — what must and must not change,
> 3. a **target** — the system the program will compile against.

A description missing one of these fields is a wish. The optimizer should treat it that way.

### 2.2 Ambiguity as a first-class feature

English is ambiguous on purpose. Programs in this language *will* be ambiguous. That is fine. The error is letting unresolved ambiguity cross the optimizer boundary.

The optimizer's job (Move 2) is to surface ambiguity as **assumptions** and write them into the IR. If an assumption survives the optimizer without being named, it has been smuggled into the build.

### 2.3 Authoring discipline

A well-formed program in this language reads like a contract:

- ✓ "Replace the deploy-finalization poll with a durable Firestore record. The runtime must remain async. No public API changes. Target: corp-platform deploy service."
- ✗ "Make deploys feel snappier."

The first program type-checks against the rest of this spec. The second starts as a wish. The optimizer may accept wishes as raw input, but it must rewrite them before compilation.

### 2.4 Author identity

The author of a program in this language can be human, LLM, another agent, or a mixed pair. The system judges the program by content instead of author. An LLM-authored program needs the same evidence and falsification bar as a human-authored one.

---

## 3. The type system: Evidence

### 3.1 The central claim

> **The type system is evidence.** A statement about the program type-checks if and only if it is evidenced.

This replaces the role of static types in a deterministic compiler. Static types normally constrain the *shape* of values. Here, evidence constrains the *truth* of claims.

### 3.2 Evidence kinds

```
Evidence ::=
    Test(spec, run)              -- a test spec linked to a recorded run
  | Log(query, range, hit)       -- a log query in a time range with hits
  | Repro(commands, output)      -- a deterministic command sequence
  | Inspection(artifact, obs)    -- direct inspection of a landed artifact
  | Reference(authority, cite)   -- a citation against a tiered authority
  | Reconciliation(claim, state) -- a claim resolved against landed state
```

Each evidence kind carries a **provenance**: who produced it, when, against what version of reality. Evidence without provenance does not type-check.

### 3.3 The evidence lattice

Evidence forms a partial order from weak to strong:

```
  "It works on my machine"   ⊑   linked test run
  "I checked it"             ⊑   repro command
  "Looks fixed"              ⊑   RCA + regression
  "Demo passed"              ⊑   gate evidence
  "Merged"                   ⊑   landed-state reconciled
```

The evidence bar is the **floor**. Claims below that bar fail type-checking. Bring stronger evidence when you have it.

### 3.4 Confabulation = type error

> **A2.** Any claim about the program that is not backed by evidence is a **confabulation**. Confabulations are type errors. They MUST be surfaced. The method MUST refuse to advance the build until they are resolved.

Confabulation is the LLM's most distinctive failure mode. This type system exists mostly to catch it.

### 3.5 The Root Rule

The author of the program — human or agent — is required to operate under:

> **Assume you are confabulating.**
> **Check facts.**
> **Then check the facts that would prove you wrong.**

Treat this as a hard requirement. It is how you inhabit the type system. Skip the third clause and you are type-blind.

---

## 4. The intermediate representation: Issue memory

### 4.1 The IR node

```
Issue := {
  id           : IssueId
  kind         : Parent | Child
  scope        : Scope
  assumptions  : List<Assumption>
  acceptance   : List<Criterion>
  falsifiers   : List<Falsifier>
  evidence     : List<Evidence>
  parent       : Option<IssueId>
  children     : List<IssueId>
  state        : Open | Implementing | Reviewing | Landed | Reconciled
  trail        : List<Event>          -- monotonic, append-only
}
```

The IR is concrete. It lives in GitHub, stays readable, stays queryable, and survives the agent, the chat, and the human who started the chat.

### 4.2 Parents vs children

Two distinct node kinds:

| | Parent | Child |
|---|---|---|
| Role | Coordination artifact | Delivery unit |
| Holds | assumptions, sequence, current map of reality | one scope, one commit, one acceptance |
| Splits into | children | nothing — children do not nest |
| Closes when | every child reconciled and assumption ledger re-validated | acceptance criteria met against landed state |

Every node in the IR has exactly one kind. "Epic" and "story" belong to planning tools. They do not belong in the IR.

### 4.3 The trail invariant

> **A3.** Every state transition on an issue MUST append an event to its trail. The trail is monotonic and immutable.

The trail turns the IR into *memory*. A snapshot alone is weak. The Bruno Method needs history because non-deterministic compilers must be reproducible from their trail.

### 4.4 Why issues, not chats

Chats decay. Prompts drift. Agents forget. Humans misremember.

The IR counters all four with a durable, named, append-only record:

- durability counters decay,
- names counter drift,
- appended transitions counter forgetting,
- durable intent counters misremembering.

That is why the issue train matters. A useful issue records more than requested work. It records the falsification criteria: what is known, what remains unknown, which claims have already failed, and what evidence would change the answer. Without that record, a later agent can accidentally resurrect a falsified statement as fresh uncertainty.

---

## 5. The optimization passes: The Five Moves

The optimizer is a sequence of five mandatory passes. Each pass has:

- **Pre**: the state of the IR before the pass may run.
- **Post**: the state of the IR after the pass has run.
- **Refusal mode**: what happens if downstream passes are attempted before this one completes.

### 5.1 Move 1 — Evidence Before Architecture

| | |
|---|---|
| Pre | Program well-formed (goal, scope, target). |
| Post | Snapshot of current behavior, recent changes, owner notes, and known incidents captured as `Evidence` in the IR. |
| Refusal | Architectural decisions made before this pass are unsound and MUST be rolled back. |

Evidence about *what is* has to precede claims about *what should be*. In type-system terms: fact before opinion.

### 5.2 Move 2 — Strategy Before Plan

| | |
|---|---|
| Pre | Move 1 complete. |
| Post | Major decisions (architecture, ownership, sequence) committed to the IR with an explicit assumption ledger. |
| Refusal | Plans (task lists) generated before this pass are *precise nonsense*. |

A plan made before a strategy is detail without direction. The optimizer refuses to generate child issues until the strategy passes its own type-check.

The Move uses two **lenses**:

- **Assumption lens** — for this to work, what must be true? For it to fail, what must be true?
- **Decision lens** — prefer fewer assumptions and decisions that are easy to undo. Occam first, reversibility second.

### 5.3 Move 3 — Issues As Memory

| | |
|---|---|
| Pre | Strategy committed. |
| Post | Parent issue + child issues created in IR. Every child has scope, acceptance, owner, and at least one falsifier. |
| Refusal | Work that exists only in chat or memo does not exist. The build MUST refuse to advance from chat-state. |

This pass is where intent becomes addressable. After Move 3 the build has a referent. Before then, it has only a conversation.

### 5.4 Move 4 — Falsification Before Confidence

| | |
|---|---|
| Pre | Children defined. |
| Post | Each child carries at least one explicit `Falsifier` — a check that would prove the child wrong if violated. |
| Refusal | Children without falsifiers are *not buildable*. The runtime MUST refuse to execute them. |

Do not confuse the falsifier with the test. The test comes downstream. The falsifier is the *commitment about reality* that retracts the work when reality violates it.

Three plan strengths, formally:

```
PlanStrength(plan) := match plan.shape with
  | "this should work"                                    → Weak
  | "this should work unless A_1, ..., A_n fail"          → Strong
  | "experiment E will tell us whether A_1..A_n hold"     → Bruno
```

Only `Bruno` plans pass the optimizer.

### 5.5 Move 5 — Closure Against Reality

| | |
|---|---|
| Pre | Implementation landed. |
| Post | Acceptance criteria reconciled against landed state; evidence linked; trail closed. |
| Refusal | "Done" without reconciliation is a lie. The build MUST refuse to mark the issue closed. |

Neither the agent nor the human gets to declare closure by fiat. The **system** declares it after reconciliation completes.

---

## 6. The debugger: Falsification

### 6.1 The debugger contract

For every claim `P` in the IR, the debugger asks:

> **What would prove `P` wrong?**

A claim that cannot answer this question is undebuggable. The optimizer rejects undebuggable plans (see Move 4).

### 6.2 Falsifiers as breakpoints

A falsifier is a runtime breakpoint. Examples:

- "If the new query returns more than 1.5× the old latency, retract."
- "If the migration touches more than the listed tables, retract."
- "If the audit log shows access from outside the scoped principals, retract."

When a falsifier triggers, the build state moves from `Implementing` or `Landed` to `Reviewing`; the trail records the trigger.

### 6.3 Falsification ≠ testing

Tests live inside the build. Falsifiers are *contracts about reality*. A passing test does not retire a falsifier; a passing falsifier does. You need both.

### 6.4 Symmetry: falsify the method itself

The method has to survive its own debugger. A method without falsifiers is a religion. Therefore:

> **A4.** The Bruno Method MUST itself name the conditions under which it would be wrong.

Candidate falsifiers for the method:

- A team consistently ships sound, reconciled, evidence-bearing work without using any of these passes.
- A class of LLM compilers becomes deterministic enough to retire the discipline.
- A simpler discipline strictly dominates this one on safety, cycle time, teachability, and adoption.

When any of these holds, this spec retires.

---

## 7. The linker: Adversarial review

### 7.1 Symbol resolution against reality

At link time, every claim is resolved against the artifact it claims to describe.

```
link(claim, landed_state) :=
  if matches(claim, landed_state) → resolved
  else → link error
```

Examples of link errors:

| Claim | Landed state | Result |
|---|---|---|
| "endpoint returns 200" | returns 500 | error |
| "no permission regression" | audit log shows new access | error |
| "RCA explains the new behavior" | RCA pre-dates the change | error |
| "no API breakage" | breaking change diff | error |

### 7.2 Three link stages

1. **Static link** — types, lints, schema validation, contract tests.
2. **Dynamic link** — integration runs, smoke checks, canary observation.
3. **Reality link** — production observation against acceptance.

A build links only after all three stages resolve.

### 7.3 The linker is adversarial

> **A5.** The linker's job is to *try to break* the build. A linker that rubber-stamps is broken.

This applies whether the linker is human review, agent review, automated check, or a mixed review chain. An adversarial review produces a falsification attempt for every claim and merges only if the attempt fails.

### 7.4 Reviewer types

Reviewers are typed:

- `Author` — proposed the change. Disqualified as adversary.
- `Sibling` — works in adjacent code. Eligible for static / dynamic adversary.
- `Owner` — accountable for the affected surface. Required for reality adversary.
- `Outsider` — disinterested, brought in to falsify the framing itself.

A small change may need only `Sibling`. Anything load-bearing requires `Owner` and benefits from `Outsider`.

---

## 8. The runtime: Agent harness

An **agent** is an LLM inside an execution loop. The LLM proposes the next action; the loop gives it tools, observes the result, updates state, and continues until the task is complete or a falsifier fires.

The useful distinction is:

| Term | Role |
|---|---|
| LLM | Compiles ambiguous intent into candidate actions. |
| Agent | Runs those candidate actions through a loop. |
| Tools | Provide capabilities such as reading, editing, searching, shelling, browsing, and calling services. |
| Harness / runtime | Bounds identity, permissions, budget, workspace, and termination. |
| Sandbox | Makes work inspectable and reversible before it lands. |
| Issues | Preserve the memory and criteria the loop cannot safely keep in context. |

This is why the compiler metaphor is operational: the LLM compiles intent into work the agent runtime executes against reality.

### 8.1 The workspace ABI

The runtime exposes a stable, well-typed interface:

```
fs        : { read, write, list, hash }
shell     : { exec, env, cwd, timeout }
bg        : { spawn, status, kill }
retrieve  : { search(ir | code | docs) }
backend   : { net, secrets, services }
```

This is the **workspace ABI**. It is stable across agents. Agents that need a non-ABI capability MUST extend the ABI explicitly; the runtime forbids ad-hoc capability acquisition.

### 8.2 Bounded execution

A child issue is a bounded execution. The runtime enforces:

- **One scope** — the runtime refuses writes outside the scope.
- **One commit boundary** — the runtime serializes changes into a single addressable commit.
- **Tool budget** — the runtime caps tool calls to a published budget.
- **Termination criteria** — the runtime stops the agent when falsifiers fire or budget exhausts.

### 8.3 Serving state is truth

> **A6.** Claims about deployed systems resolve against the system's *serving state*.

Cleanup bookkeeping, stale review state, the last log line, and the agent's conclusion are all weaker than serving state.

The runtime's job is to **expose serving state**. Every claim resolves through the runtime, against the serving state, at the time of resolution.

### 8.4 Why a runtime, not a tool

A runtime needs more than a bag of tools:

- A consistent ABI.
- An identity model.
- A budget model.
- A termination model.
- A reconciliation model.

Without all five, the result is a prompt-engineering trick.

### 8.5 Public case evidence

The public deck uses case evidence as existence proof while protecting sensitive source material. The pattern is:

| Case evidence | Method pressure |
|---|---|
| Platform metadata loss | Postmortems need tracked remediation and closure evidence. |
| Public serving drift | Deployed truth must be reconciled against control-plane intent. |
| Public GPU launch readiness | Launch claims need owners, gates, blocker lists, and go/no-go criteria. |
| Evidence retrieval work | Search systems need authority ranking, analyst runtime, verifier discipline, and citation hygiene. |
| Hybrid video retrieval | Plausible ranking ideas must lose to benchmark evidence when they do not improve quality. |

Specific project names, unreleased product names, customer data, credentials, and repository details stay out of the public case evidence. The deck keeps the method shape and removes the source nouns.

The case slides ground that shape with short issue-train excerpts. They show method mechanics after public-safe filtering: a parent claim, child scope, falsifier, gate, or closure criterion.

---

## 9. The build system: Issue graph

### 9.1 The DAG

```
nodes  : issues
edges  : parent → child  ∪  child → child (dependency)
roots  : parent issues
leaves : reconciled children
```

The graph is the build. Imagine `make` with a memory of non-determinism.

### 9.2 Reproducibility

A build is **reproducible** when its issue graph + commit graph + evidence trail are sufficient to recompute its outcome up to the LLM's non-determinism budget.

Note the asterisk: reproducible *up to* non-determinism. The artifacts may not be byte-identical. The *acceptance* can still be stable because evidence type-checks it across recompilations.

### 9.3 Closure

A build closes when:

1. Every leaf is `Reconciled`.
2. Every parent's assumption ledger has been re-validated against landed state.
3. The trail has been written to durable storage.

A build that meets (1) and (2) while missing (3) is complete work with fragile memory. Leave it open.

### 9.4 Trains

In practice, builds are organized into **issue trains**: groups of parents that share a release boundary. The train sits above the DAG. It does not change the type system; it batches reconciliation.

---

## 10. Soundness and completeness

### 10.1 What the method guarantees

- **Soundness** — claims that pass the evidence bar are not confabulations.
- **Reproducibility** — a build can be replayed from its IR and trail (up to non-determinism).
- **Locality** — a child's failure stays inside the child until the parent re-runs reconciliation.
- **Falsifiability** — every plan exposes the experiment that could disprove it.

### 10.2 What the method does *not* guarantee

- The LLM emits the same artifact twice. (See A1.)
- A sound plan is the *right* plan.
- Falsifiers cover all possible failures.
- The author of the program is a good author.

The method narrows the failure envelope. It cannot eliminate it.

### 10.3 Known unsoundness modes

Even with the method:

- **Falsifier blindness** — a class of failures that no falsifier names. Mitigation: outsider review.
- **Evidence drift** — evidence that was strong yesterday is weak today (e.g., expired logs). Mitigation: re-link before close.
- **Authority collapse** — a tier-1 reference becomes wrong (e.g., upstream change). Mitigation: re-tier on revalidation.

A future revision of this spec will name these in the type system as `Stale(Evidence)` and `Revoked(Reference)`.

---

## 11. Anti-patterns: programs that do not compile

| Anti-pattern | Why it does not compile |
|---|---|
| "Use an agent" | No goal, no scope, no target. Section 2.1. |
| "Make it work" | No acceptance. Section 4.1. |
| "Buying agents will not give you agency" | Tooling without method. C1. |
| "Demo passed" | Link-time short-circuit. Section 7.1. |
| "Merged" | Linker bypassed reality. Section 7.2. |
| "It works on my machine" | Floor of evidence not met. Section 3.3. |
| "I checked it" | Unverifiable evidence. Section 3.3. |
| "We'll test it later" | Falsifier missing. Section 5.4. |
| "The agent says it's done" | Serving state not consulted. A6. |
| "Trust the model" | Discipline corollary inverted. C1. |

These are type errors, not stylistic objections. A build that contains any of them is still a draft.

---

## 12. Distance to the method

### 12.1 The metric

Practitioner distance to the method is a vector in six dimensions, each measured from {weak, partial, solid, strong}:

```
distance(practitioner) =
  ⟨ falsifiesPlans
  , findsRootCause
  , leavesTrail
  , gatesClaims
  , slicesWork
  , reviewsHard
  ⟩
```

No single number captures this. The polygon's shape is the practitioner's profile. (See deck slide 36, "Distance To The Method.")

### 12.2 The hiring use

For hiring, the question reduces to:

> **What is `distance(candidate)` and how does it move under coaching?**

That is more useful than "can you use AI." Every candidate can learn the tool. Far fewer can compress the polygon under pressure.

### 12.3 The team use

For teams, the metric aggregates pointwise. A team's polygon takes the **min** across members per dimension. One weak axis can defeat the build, the way one failing test defeats the suite.

### 12.4 The self use

For the practitioner, the metric is reflective. The honest version of "How am I doing?" is:

> **On which axis do I most often skip?**

That axis is the next thing to harden.

---

## 13. Summary

The compiler changed.

We got a different compiler: one that accepts English, emits artifacts, remembers unevenly, and refuses to be deterministic.

The discipline this document specifies is what makes that compiler safe enough to use:

- **A1**: It is non-deterministic.
- **A2**: Confabulations are type errors.
- **A3**: Every transition is appended to the trail.
- **A4**: The method names the conditions under which it would be wrong.
- **A5**: The linker is adversarial.
- **A6**: Serving state is truth.

The rest follows from those claims.

---

## Appendix A — Bibliography of the deck

This specification restates the *Bruno Method* deck in a stricter form. The mapping:

| Deck slide | Spec section |
|---|---|
| Hero, "Engineering in the Compiler Age" | Section 1 |
| Why This Matters | Section 11 |
| Field Evidence / What The Issues Preserve | Sections 4.4, 8.5 |
| The Claim: discipline around the model | C1 |
| The Compiler Changed (timeline) | Section 1.4 |
| The LLM Is A Compiler | Section 1, A1 |
| What Is An Agent? | Section 8 |
| This Compiler Is Weird | Section 1.4 |
| The Old Discipline / The New Discipline | Section 3 |
| The Compiler Stack | Section 1.1 |
| The Dangerous Mistake / Tools Need Discipline | C1, Section 11 |
| The Bruno Method (definition) | Section 0–13 (entire spec) |
| The Five Moves | Section 5 |
| Move 1 / Root Rule | 5.1, 3.5 |
| Move 2 / Assumption Lens / Decision Lens | 5.2 |
| Move 3 / Issue Train / Parent And Child | 4, 5.3 |
| Move 4 / A Better Plan | 5.4, 6.1 |
| Move 5 / Evidence Bar | 5.5, 3.3 |
| Case Studies (NAP, NAP Next Generation, FTC, BADAS, Hybrid Search) | Section 8.5; cases are public-safe existence proofs of the spec |
| Case Issue Trains | Sections 4.4, 5.3, 8.5, 9; excerpts show how issue memory carries falsifiers and evidence |
| The Pattern | Section 5 (passes are case-independent) |
| Hiring Is Hidden / Distance To The Method | Section 12 |
| Close vs Far | 12.1 |
| The Change | Sections 1.1–1.4 |
| What To Teach / What To Say Out Loud | Section 13 |
| What Changes | Section 5 (each move is a practical change) |
| The Promise | Sections 9, 10 |

---

## Appendix B — Open questions

A working spec should admit what it has not solved yet:

1. **Evidence staleness** — when does `Evidence` expire? The current spec treats it as immortal. Reality does not.
2. **Cross-build symbol resolution** — how does the linker resolve a claim whose landed state lives in a different build's reconciliation? Today: by hand. The spec has no answer.
3. **Multi-author programs** — when human and agent co-author a program, whose authoring discipline applies? The spec says "type by content"; in practice the framing matters.
4. **Compiler versioning** — when the LLM compiler upgrades, prior builds may fail to recompile. We do not yet treat the LLM as a versioned dependency. We should.
5. **Method drift** — the method itself changes as the compiler changes. The spec needs its own falsification protocol.

These are the next things to work on. They also test distance to the method: a practitioner close to it will treat them as work, not as faults of the deck.

---

*End of specification.*
