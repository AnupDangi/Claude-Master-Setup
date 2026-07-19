---
description: Pause the build loop mid-work — persist why, stop agents, wait for human clarity
argument-hint: [optional: reason]
allowed-tools: Read, Write, Edit, Bash(bash */scripts/*.sh:*), Bash(bash scripts/:*), Bash(./scripts/:*)
model: sonnet
---

# Pause the loop

Use when the human interrupts, or when you (or a specialist) are confused /
blocked and must not invent a design.

Current: !`test -f .master/state/loop.json && head -c 800 .master/state/loop.json || echo "no loop.json — run /master:bootstrap first"`

## Steps

1. If `.master/state/loop.json` is missing, say so and stop.
2. Read current `phase` and `task`. Summarize in one paragraph: what was in
   progress, what is done, what is blocked.
3. Update `.master/state/loop.json`:
   - `phase`: `paused` (or `await_human_clarify` if you need answers)
   - `pause_reason`: the human's reason argument, or your own blocked reason
   - `await_clarify_questions`: optional JSON array of numbered questions
4. Emit: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/loop-event.sh pause '{"reason":"..."}'`
5. Tell the human: answer the questions (if any), then `/master:status` and
   `/master:loop` to resume. Do **not** continue BUILD in this turn.

## Do Not

- Do not keep writing feature code after pausing.
- Do not silently change architecture — use `/master:decide` for that.
