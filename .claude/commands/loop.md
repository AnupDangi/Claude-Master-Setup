---
description: Start or resume the plan→build→validate→review→commit build loop
argument-hint: [optional: task or roadmap item to target] [optional: max-retries=N]
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
3. If `$ARGUMENTS` includes `max-retries=N`, use `N` as the validation retry cap for this run instead of `$HARNESS_MAX_VALIDATE_RETRIES` (default 3).
4. Honor both approval gates (plan approval, merge approval) and the hard validation gate. **Stop and wait at each gate** — do not auto-proceed.
5. If VALIDATE goes RED `max_validate_retries` times in a row on the same task, stop looping BUILD→VALIDATE and escalate to the human (`await-human-on-red`) instead of retrying forever.
6. After each iteration, ensure `docs/PROJECT_STATE.md` and `.claude/state/loop.json` reflect reality before continuing.
7. Stop when the roadmap has no unblocked work, or when a gate needs the human — whichever comes first.
