# Subagents

Eleven self-contained specialists in `.claude/agents/`. Each is a Markdown file:
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
| **implementer** | sonnet | Read/Write/Edit + test runners | BUILD phase, default (only code-writers) |
| **implementer-opus** | opus | Read/Write/Edit + test runners | BUILD phase, when `task_complexity` is `large` |
| **validator** | sonnet | Read, Bash(scripts + test runners) | VALIDATE phase, `/validate` |
| **reviewer** | sonnet | Read, git diff (read-only) | REVIEW phase, `/review` |
| **security** | opus | Read, git diff (read-only) | Sensitive changes, `/review` |
| **docs-writer** | haiku | Read, Write/Edit (docs only), git log | COMMIT phase, `/handoff` |
| **mcp-scout** | sonnet | Read, WebSearch, Write(`.mcp.json`), scripts | External tool needs, `/mcp-add` |
| **evaluator** | sonnet | Read, git log/diff (read-only) | `/evaluate` (objective metrics only) |

## Design principles

- **Least privilege.** Read-only agents (planner, validator, reviewer, security,
  evaluator) cannot write code. Only `implementer`/`implementer-opus` write
  feature code — never both on the same task at once; only `architect`/
  `docs-writer` write docs; only `mcp-scout` writes `.mcp.json`. This bounds
  the blast radius of any single agent.
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
                       ├─▶ implementer OR implementer-opus  ◀── fix loop ── validator
                       │     (picked once per task by task_complexity; never both)
                       ├─▶ validator  (hard gate)
                       ├─▶ reviewer + security
                       └─▶ docs-writer  (+ mcp-scout when a tool is needed)

/evaluate ─▶ evaluator  (objective metrics only — read-only, standalone)
```

## Planned roles

**Scheduler — not yet built.** The target design in
[`LOOP_ENGINE.md`](LOOP_ENGINE.md) generalizes `orchestrator`'s SELECT step
(today: scan the roadmap top-to-bottom, skip blocked/dependency-unsatisfied
items, pick the first left — see `docs/LOOP.md`) into a Scheduler that ranks
candidates by value/risk signals, estimates cost, and routes to a model
dynamically (see [`MODEL_ROUTING.md`](MODEL_ROUTING.md)) instead of a static
per-agent pin. Until it exists, `orchestrator` continues to own goal selection
exactly as described in `docs/LOOP.md`.

## Extending

Add a new agent by dropping a Markdown file in `.claude/agents/`. Keep the tool list
minimal, write the description as a trigger condition, and pin the cheapest capable
model. Run `bash scripts/self-check.sh` after adding one. If several agents overlap
in description, Claude may pick the wrong one — keep scopes distinct.

Common additions: a language-specific reviewer (`python-reviewer`, `react-reviewer`),
a `data-migration` specialist, a `perf-profiler`, or a `release-manager`.
