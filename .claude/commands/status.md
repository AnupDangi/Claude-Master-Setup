---
description: Show compact project, loop, validation, and handoff status
allowed-tools: Read, Bash(cat:*), Bash(git branch:*), Bash(git status:*)
model: haiku
---

# Status

- Project: !`cat .master/project.json 2>/dev/null || echo "not bootstrapped"`
- Loop: !`cat .master/state/loop.json 2>/dev/null || echo "no loop state"`
- Handoff: !`cat .master/state/handoff.json 2>/dev/null || echo "no handoff"`
- Branch: !`git branch --show-current 2>/dev/null || echo "not a git branch"`
- Changes: !`git status --short 2>/dev/null || echo "git status unavailable"`

Summarize in at most five lines: project/maturity, loop iteration/status, validation,
blocker, and next action. Do not read additional docs.
