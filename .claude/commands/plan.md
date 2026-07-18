---
description: Plan the next task without building it (planner only)
argument-hint: [roadmap item or feature to plan]
allowed-tools: Read, Grep, Glob, Task
model: opus
---

# Plan Only

Roadmap context: !`sed -n '1,40p' docs/ROADMAP.md 2>/dev/null || echo "no ROADMAP yet"`
Local skills: !`bash scripts/list-local-skills.sh 2>/dev/null | head -c 4000 || echo "[]"`

**Intent:** produce an executable plan for the named work (no code).

Delegate to the **planner** subagent using `docs/templates/AGENT_TASK.md`. Include
relevant local skills (from the index above; max 3) under Relevant Skills.
Planner may spawn ≤3 nested read-only research Tasks. See
`docs/CAPABILITY_ORCHESTRATION.md`.

Plan target:

$ARGUMENTS

Return the full plan (Task, Approach, Files, Tests, Dependencies, Definition of
Done, Out of scope, Recommended skills, Fan-out or null). Do **not** write any
code. If a dependency looks like it needs an external tool, flag it as a
candidate for `/mcp-add`. Stop after presenting the plan.
