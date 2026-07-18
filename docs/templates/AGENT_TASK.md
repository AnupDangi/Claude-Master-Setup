# Task

## Objective

Exactly what must be accomplished in this Task (one shippable outcome).

## Context

Why this Task exists now (roadmap item, loop phase, parent Task if nested).

## Inputs

- Files / paths to read
- Prior summaries or plans
- `loop.json` fields that matter (`task`, `task_graph`, `fanout`, skills)

## Constraints

Rules that bind this Task (gates, least privilege, coding standards, DoD).

## Relevant Skills

Local Claude Code skills to consult first (max 3). Use paths from
`scripts/list-local-skills.sh` / `loop.json.skills_index`. If none:

- _(none)_

## Expected Output

What the agent must return to its parent (structured summary, plan sections,
diff summary, scorecard — not freeform chat).

## Validation Requirements

How success will be checked (tests to add, `validate.sh`, review criteria).

## Do Not

Explicit out-of-scope: files not to touch, gates not to skip, work not to expand.

---

<!-- Worktree children only (implementer fan-out slices) -->

## Worktree Path

Absolute path to this slice's worktree (from `worktree-fanout.sh`).

## Branch

Slice branch name.

## Owned Files

Paths this child may create or edit (must match the approved fan-out slice).

## Do Not Touch

Paths owned by sibling slices — never edit these.
