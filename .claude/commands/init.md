---
description: Scaffold this project's .master/ folder (state + starter docs) — needed once before /master:bootstrap
allowed-tools: Read, Write, Edit, Bash(test:*), Bash(mkdir:*), Bash(cp:*), Bash(git:*)
model: sonnet
---

# Initialize `.master/`

Already scaffolded check: !`test -f .master/docs/PROJECT_STATE.md && echo ".master/docs/PROJECT_STATE.md found — already scaffolded" || echo "not scaffolded yet — will create .master/"`

## Why this command exists

The harness framework (agents, commands, scripts, hooks) lives **once**, shared —
via the Claude Code **plugin** (recommended) or `npx claude-master-setup`. It is
never copied into your app.

Every project still needs its own memory:

- `.master/state/` — loop machine state (`loop.json`, leases, events) — gitignored
- `.master/docs/` — this project's ROADMAP, PROJECT_STATE, DECISIONS, … — committed
- `CLAUDE.md` — stable project conventions

## Steps

1. If `.master/docs/PROJECT_STATE.md` already exists, stop and say:
   "Already scaffolded — run `/master:bootstrap` next." Do not overwrite.
2. Otherwise create `.master/state/` and write full `.master/state/loop.json`:
   ```json
   { "iteration": 0, "phase": "idle", "task": null, "validate_attempts": 0, "max_validate_retries": 3, "task_graph": null, "task_complexity": null, "plan_source": null, "review_dispatch": null, "skills_index": null, "skills_assigned": [], "skills_skipped": [], "fanout": null, "iterations_this_run": 0, "max_iterations_per_run": 1, "build_effort_tier": null, "build_effort_score": null, "docs_profile": null }
   ```
   If `loop.json` already exists but is missing `"phase"`, merge these defaults
   in (do not wipe existing build_effort fields).
3. Create `.master/docs/` and copy stubs from
   `${CLAUDE_PLUGIN_ROOT}/templates/master-docs/` (PROJECT_STATE, ROADMAP,
   DECISIONS, ARCHITECTURE, CODING_STANDARDS, SECURITY, TESTING, SESSION,
   HANDOFF, CHANGELOG) — skip files that already exist.
4. Create `./CLAUDE.md` from `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.starter`
   only if missing.
5. Ensure `.gitignore` includes: `.env`, `.env.*`, `!.env.example`, `.master/state/`.
6. Report done → tell the human to run `/master:bootstrap` next.

## Do Not

- Do not overwrite existing project files.
- Do not auto-run `/master:bootstrap`.
- Do not copy `scripts/`, framework `docs/`, or hooks into the project.
- Do not touch `.env` or print secrets.
