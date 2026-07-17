---
description: Start or resume the plan→build→validate→review→commit build loop
argument-hint: [optional: task or roadmap item to target]
allowed-tools: Read, Grep, Glob, Task, TodoWrite, Bash(git:*), Bash(bash scripts/:*)
model: opus
---

# Build Loop

Current state:
- Loop state: !`cat .claude/state/loop.json 2>/dev/null || echo "no state yet (fresh start)"`
- Roadmap (top): !`sed -n '1,40p' docs/ROADMAP.md 2>/dev/null || echo "docs/ROADMAP.md missing — run /bootstrap first"`
- Uncommitted changes: !`git status --short 2>/dev/null | head -20`

## Your task

Delegate to the **orchestrator** subagent to run one or more iterations of the build loop defined in `docs/LOOP.md`.

$ARGUMENTS

Rules for this run:
1. Read `CLAUDE.md`, `docs/PROJECT_STATE.md`, and `docs/DECISIONS.md` first if you haven't this session.
2. If `$ARGUMENTS` names a specific task, target that; otherwise pick the next unblocked roadmap item.
3. Honor both approval gates (plan approval, merge approval) and the hard validation gate. **Stop and wait at each gate** — do not auto-proceed.
4. After each iteration, ensure `docs/PROJECT_STATE.md` and `.claude/state/loop.json` reflect reality before continuing.
5. Stop when the roadmap has no unblocked work, or when a gate needs the human — whichever comes first.
