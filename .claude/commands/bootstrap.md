---
description: Turn PRD.md + PTR.md into the full engineering foundation (no code yet)
allowed-tools: Read, Grep, Glob, Task, Write, Edit
model: opus
---

# Bootstrap the Project

Requirements present:
- PRD: !`test -f PRD.md && echo "PRD.md found" || echo "PRD.md MISSING"`
- PTR: !`test -f PTR.md && echo "PTR.md found" || echo "PTR.md MISSING"`

Follow `MASTER-PROMPT.md` end to end using `PRD.md` and `PTR.md` as the only source of truth.

Delegate to the **architect** subagent for the architecture review and technology validation, then generate: `CLAUDE.md` (if not already project-specific), the full `docs/` set, and `docs/ROADMAP.md` as an ordered, small-task build plan the loop can consume.

**Do not write implementation code.** Ask clarifying questions on anything ambiguous and stop for approval before finishing. The deliverable is a repository that already knows what it is.
