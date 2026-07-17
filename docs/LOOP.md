# The Build Loop

This harness treats development as an **engineered loop**, not a freeform chat.
Each turn of the loop produces one small, validated, reviewed, documented increment
and leaves the repository fully describing its own state. Run it with `/loop`.

```
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ┌─────────┐   ┌──────┐   ┌═══════════┐   ┌───────┐   ┌──────────┐│
   │ SELECT  │──▶│ PLAN │──▶║  GATE 1   ║──▶│ BUILD │──▶│ VALIDATE ││
   │ next    │   │      │   ║ approve   ║   │ code  │   │  (hard   ││
   │ task    │   │      │   ║ the plan  ║   │ +tests│   │   gate)  ││
   └─────────┘   └──────┘   └═══════════┘   └───────┘   └────┬─────┘│
                                                ▲            │       │
                                          RED   │            │ GREEN │
                                         (fix)  └────────────┘       │
                                                                     ▼
   ┌──────┐   ┌═══════════┐   ┌────────┐   ┌────────────────┐   ┌────────┐
   │ LOOP │◀──│ update    │◀──│ COMMIT │◀──║   GATE 2       ║◀──│ REVIEW │
   │      │   │ state/docs│   │ atomic │   ║ approve merge  ║   │ +sec   │
   └──┬───┘   └───────────┘   └────────┘   └════════════════┘   └────────┘
      │                                                             ▲
      └─────────────────────────────────────────────────────────────┘
                     (Critical/High findings loop back to BUILD)
```

## Phases

### 1. SELECT
The orchestrator reads `docs/ROADMAP.md` and `docs/PROJECT_STATE.md` and picks the
**single smallest shippable unit** that is unblocked. It states what it picked and
why. If nothing is unblocked, the loop stops and reports.

### 2. PLAN
Delegates to `planner` (and `architect` first if the task is architecturally
significant). Output: the files to touch, the tests to write, dependencies, and a
Definition of Done. No code is written yet.

### GATE 1 — approve the plan
The plan is presented to you in a tight summary. **The loop stops here** until you
approve. Silence is not approval. This is where you catch a wrong direction before
any code exists — the cheapest possible place to correct course.

### 3. BUILD
Delegates to `implementer`, which writes the code **and** its tests for exactly this
task — nothing more. Scope creep is rejected here.

### 4. VALIDATE — the hard gate
Delegates to `validator`, which runs `scripts/validate.sh` (format, lint, typecheck,
tests, build — auto-detected per stack).

- **GREEN (exit 0):** the gate opens; proceed to REVIEW.
- **RED (any non-zero):** the gate stays shut. The failure report goes back to
  BUILD. The loop **cannot** advance. Repeat BUILD → VALIDATE until GREEN.

GREEN is binary. There is no "green with warnings" and no skipping a check to pass.

### 5. REVIEW
Delegates to `reviewer` (always) and `security` (when the change touches auth, input
handling, secrets, payments, uploads, or data access). Both are read-only and return
severity-ranked findings. **Critical/High findings loop back to BUILD.**

### GATE 2 — approve the merge
You see the diff summary, the GREEN gate result, and the review findings. **The loop
stops here** until you approve the commit/merge.

### 6. COMMIT
One atomic commit with a conventional message. Then `docs-writer` updates
`docs/PROJECT_STATE.md`, `docs/CHANGELOG.md`, `docs/SESSION.md`, and
`docs/DECISIONS.md` (if a decision was made).

### 7. LOOP
Back to SELECT. Continue until the roadmap has no unblocked work.

## Invariants (always true between iterations)

1. The repository fully describes project state — a fresh session can continue with
   zero conversation history.
2. `main` (or the working branch) is never left with a RED gate committed.
3. Every committed code change has tests and a docs update in the same iteration.
4. `.claude/state/loop.json` reflects the true current phase.

## State file

`.claude/state/loop.json` (gitignored, worktree-local) tracks the loop:

```json
{ "iteration": 7, "phase": "review", "task": "add password reset endpoint", "gate": "awaiting-merge-approval" }
```

`phase` ∈ `idle | select | plan | await-plan-approval | build | validate | review | await-merge-approval | commit`.

## Autonomy dial

Default: **interactive with two approval gates** — safest, and what ships here.

To run more autonomously in a trusted, well-scoped project, you can tell the
orchestrator to auto-approve GATE 1 for low-risk tasks (still never GATE 2 for
anything touching security/data). To run *less* autonomously, ask it to pause after
every phase. The validation gate is never optional at any autonomy level.

## When something breaks the loop

- **Gate keeps going RED on the same failure:** stop the loop, investigate the root
  cause manually (or with `/review`), and only then resume. Do not loosen the check.
- **Plan turns out wrong mid-BUILD:** implementer stops and reports; return to PLAN.
- **A task is too big:** planner splits it; the loop takes the first slice only.
