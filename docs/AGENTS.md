# Subagents

Nine self-contained specialists in `.claude/agents/`. Each is a Markdown file:
YAML frontmatter (name, description, tools, model) + a system-prompt body. The
`description` drives automatic delegation — Claude routes to an agent when the task
matches it. You can also invoke one explicitly: *"Use the security subagent on this
diff."*

No external plugin is required. Editing an agent file takes effect on the next
session (restart to pick up changes to a file that existed at session start).

## Roster

| Agent | Model | Tools (scope) | Fires at |
|---|---|---|---|
| **orchestrator** | opus | Read, Grep, Glob, Task, TodoWrite, git | `/loop` — the whole cycle |
| **planner** | opus | Read, Grep, Glob, Task (read-only) | PLAN phase, `/plan` |
| **architect** | opus | Read, Grep, Glob, WebSearch, Write(docs) | Significant design decisions, `/bootstrap` |
| **implementer** | sonnet | Read/Write/Edit + test runners | BUILD phase (only code-writer) |
| **validator** | sonnet | Read, Bash(scripts + test runners) | VALIDATE phase, `/validate` |
| **reviewer** | sonnet | Read, git diff (read-only) | REVIEW phase, `/review` |
| **security** | opus | Read, git diff (read-only) | Sensitive changes, `/review` |
| **docs-writer** | haiku | Read, Write/Edit (docs only), git log | COMMIT phase, `/handoff` |
| **mcp-scout** | sonnet | Read, WebSearch, Write(`.mcp.json`), scripts | External tool needs, `/mcp-add` |

## Design principles

- **Least privilege.** Read-only agents (planner, validator, reviewer, security)
  cannot write code. Only `implementer` writes feature code; only `architect`/
  `docs-writer` write docs; only `mcp-scout` writes `.mcp.json`. This bounds the
  blast radius of any single agent.
- **Isolated context.** Each subagent runs in its own context window and returns a
  summary. Noisy work (reading 30 files, full test logs) stays out of the
  orchestrator's context, so the main thread stays focused and cheap.
- **Model fit.** Mechanical work runs on Haiku; implementation and review on Sonnet;
  judgment-heavy work (architecture, security, planning, orchestration) on Opus.
- **Description = trigger.** Each `description` is written as a use-condition
  ("MUST BE USED for…", "Use PROACTIVELY when…") so Claude delegates reliably.

## Delegation map

```
/loop ─▶ orchestrator ─┬─▶ planner ──(architect for big calls)
                       ├─▶ implementer  ◀── fix loop ── validator
                       ├─▶ validator  (hard gate)
                       ├─▶ reviewer + security
                       └─▶ docs-writer  (+ mcp-scout when a tool is needed)
```

## Extending

Add a new agent by dropping a Markdown file in `.claude/agents/`. Keep the tool list
minimal, write the description as a trigger condition, and pin the cheapest capable
model. Run `bash scripts/self-check.sh` after adding one. If several agents overlap
in description, Claude may pick the wrong one — keep scopes distinct.

Common additions: a language-specific reviewer (`python-reviewer`, `react-reviewer`),
a `data-migration` specialist, a `perf-profiler`, or a `release-manager`.
