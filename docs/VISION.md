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

**Permissions stance (AI OS):** Claude Code's `acceptEdits` (project default) and
optional user-level `auto` mode are the right UX for long builds — click fatigue
is not a security model. Real control is harness gates, iteration budget, hooks,
and deny/ask lists. Never ship `bypassPermissions` as a project default. Details:
[`SECURITY.md`](SECURITY.md).

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
- An **evaluation framework** with objective metrics and scorecard→SELECT
  feedback — see [`EVALUATION.md`](EVALUATION.md).
- An **AI OS control plane** — event log, leases, budget stop, hard path
  blocking, harness CI, brownfield bootstrap — see [`AI_OS.md`](AI_OS.md).

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

**Shipped:** linear loop + Task Graphs + capability orchestration + AI OS
control plane (events, leases, budget, scorecard bias, hard path block, CI,
brownfield bootstrap). SELECT still prefers file-order among unblocked items,
with optional scorecard bias — not a full multi-item Scheduler.

**Still target:** value/risk Scheduler, richer cost estimation, dynamic model
routing at scale — see [`LOOP_ENGINE.md`](LOOP_ENGINE.md). Nothing here is
shipped unless also described in `LOOP.md`, `AI_OS.md`, `AGENTS.md`, or
`SETUP.md`.

## Long-term positioning

Not "a Claude Code setup." An **autonomous software engineering harness** /
AI OS layer on Claude Code. The Scheduler in [`LOOP_ENGINE.md`](LOOP_ENGINE.md)
is the remaining big piece; measurement and control-plane primitives are in
[`EVALUATION.md`](EVALUATION.md) and [`AI_OS.md`](AI_OS.md). Emphasis:
planning, execution, validation, measurement, and continuous improvement —
not prompting technique.
