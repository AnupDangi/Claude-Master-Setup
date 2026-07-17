---
description: Plan the next task without building it (planner only)
argument-hint: [roadmap item or feature to plan]
allowed-tools: Read, Grep, Glob, Task
model: opus
---

# Plan Only

Roadmap context: !`sed -n '1,40p' docs/ROADMAP.md 2>/dev/null || echo "no ROADMAP yet"`

Delegate to the **planner** subagent to produce a concrete step plan for:

$ARGUMENTS

Return the full plan (Task, Approach, Files, Tests, Dependencies, Definition of Done, Out of scope). Do **not** write any code. If a dependency looks like it needs an external tool, flag it as a candidate for `/mcp-add`. Stop after presenting the plan.
