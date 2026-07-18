# Vision

## What this is

Claude Master Setup transforms Claude Code into an **autonomous software
engineering harness** — clone it, drop in requirements, and it plans, builds,
validates, reviews, documents, and commits work as a repeatable engineered loop
instead of a sequence of one-off prompts. It should be installable into any
repository and immediately understand what the project is, how it's built,
what needs to happen next, how to verify correctness, how to record decisions,
and when to stop and ask a human.

The user provides goals. The harness handles the engineering.

## Why it exists

Without a harness, every session restarts the same loop by hand:

```
Prompt → Code → Prompt → Code → Prompt → Code …
```

Quality depends on whoever is prompting remembering to ask for tests, to check
the diff, to update the docs, to think about security. Nothing enforces it,
and nothing survives when the conversation ends.

With the harness:

```
Goal → Plan → [approve] → Build → Validate (hard gate) → Review → [approve] → Commit
```

The same quality bar applies every time, whether it's iteration 1 or iteration
100, because it's enforced by the loop and recorded in the repository — not
held in a human's memory of what to ask for.

## Design philosophy

The project is not a collection of clever prompts. It's a set of systems:

- A **build loop** that turns one roadmap item into one validated, reviewed,
  documented commit — see [`LOOP_ENGINE.md`](LOOP_ENGINE.md).
- A **state engine** so the repository, not the conversation, is the source of
  truth for where the project stands — see [`STATE_ENGINE.md`](STATE_ENGINE.md).
- A **subagent roster** of least-privilege specialists, each with a narrow job
  and the minimum tools to do it — see [`AGENTS.md`](AGENTS.md).
- **Model routing** that matches task complexity to the cheapest capable model
  — see [`MODEL_ROUTING.md`](MODEL_ROUTING.md).
- A **memory model** with one home per fact, so knowledge doesn't drift or
  duplicate across layers — see the "Four memory layers" in [`../CLAUDE.md`](../CLAUDE.md).
- An **evaluation framework** to measure engineering quality objectively
  instead of asserting it — see [`EVALUATION.md`](EVALUATION.md) (designed,
  not yet built).

The recurring question is not "how do I write a better prompt for this?" but
"how do I design a better loop, gate, or measurement for this?"

## System architecture

```
        User
          │  goals, PRD/PTR, approvals at two gates
          ▼
    Orchestrator            ◀── reads docs/ROADMAP.md, docs/PROJECT_STATE.md
          │
          ▼
  Planner / Architect        (plan the next shippable unit — no code yet)
          │
     [ GATE 1: human approves the plan ]
          │
          ▼
     Implementer            (writes code + tests for exactly one task)
          │
          ▼
      Validator              (scripts/validate.sh — hard, binary gate)
          │
          ▼
  Reviewer / Security        (severity-ranked findings, read-only)
          │
     [ GATE 2: human approves the merge ]
          │
          ▼
      Commit                 (one atomic commit)
          │
          ▼
    docs-writer               (PROJECT_STATE, CHANGELOG, SESSION, DECISIONS)
          │
          ▼
   back to Orchestrator (LOOP)
```

This is the architecture of **the harness itself** — how it is built, not what
it builds. Once you run `/bootstrap` on a real project, that project's own
architecture is documented separately in `docs/ARCHITECTURE.md` (a per-project
template filled in at bootstrap time) and in `CLAUDE.md`'s "Architecture
overview" section — don't confuse the two.

## Current state vs. target

Today, "select the next task" is a single step inside the orchestrator: it
reads the roadmap and picks the topmost unblocked item, one task at a time.
The target design generalizes this into a **Scheduler** — see
[`LOOP_ENGINE.md`](LOOP_ENGINE.md) for exactly what exists now (the linear
loop, the validation retry cap) versus what's designed but not yet built (task
graphs, cost estimation, dynamic model routing, the evaluation scorecard).
Nothing in this document should be read as already shipped unless it's also
described that way in `LOOP.md`, `AGENTS.md`, or `SETUP.md`.

## Long-term positioning

Not "a Claude Code setup." An **autonomous software engineering harness** —
and, if the Scheduler, task graph, and evaluation framework in
[`LOOP_ENGINE.md`](LOOP_ENGINE.md) and [`EVALUATION.md`](EVALUATION.md) get
built out fully, eventually an agent operating system for software
engineering. The emphasis is on planning, execution, validation, measurement,
and continuous improvement — not on prompting technique.
