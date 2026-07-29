---
description: Compatibility alias for starting an Agent Master run
argument-hint: "GOAL"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Loop Compatibility

`/loop` is retained for existing users. Start the portable run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" start "$ARGUMENTS" --agent claude-code
```

Then run status as JSON, verify it against git, and continue from `next_action`. Use Claude subagents or worktrees only when they help; the universal core does not require them.
