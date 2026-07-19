---
description: Scaffold local harness files (scripts/, docs/, hooks, state) into this project — needed once when installed via the Claude Code plugin
allowed-tools: Read, Write, Edit, Bash(test:*), Bash(mkdir:*), Bash(cp:*), Bash(chmod:*), Bash(git:*), Bash(bash scripts/:*)
model: sonnet
---

# Initialize Local Harness Files

Already scaffolded check: !`test -f scripts/validate.sh && echo "scripts/validate.sh found — already scaffolded, nothing to do" || echo "not scaffolded yet — will copy harness files into this project"`

## Why this command exists

Installing this harness as a Claude Code **plugin** (`claude plugin install master@claude-master-setup`) gives you the namespaced `/master:*` commands and 11 subagents immediately — but the actual gated loop needs project-local files: `scripts/validate.sh` (the hard gate), `docs/` (project memory), and `.claude/hooks/*.sh` + `.claude/settings.json` (the safety guards). Those are intentionally per-project, not global — this harness's whole identity is "self-contained files in your repo," not a background daemon. If you installed via `npx claude-master-setup --local` instead, those files already exist and this command is a no-op.

## Steps

1. If `scripts/validate.sh` already exists (see check above), stop immediately and tell the human: "Already scaffolded — run `/master:bootstrap` next." Do not touch or overwrite anything.
2. Otherwise, copy from this plugin's own bundled copy into the current project root, **skipping any path that already exists** — never overwrite a file the user already has:
   - `${CLAUDE_PLUGIN_ROOT}/scripts` → `./scripts`
   - `${CLAUDE_PLUGIN_ROOT}/docs` → `./docs`
   - `${CLAUDE_PLUGIN_ROOT}/.claude/hooks` → `./.claude/hooks`
   - `${CLAUDE_PLUGIN_ROOT}/.claude/context` → `./.claude/context`
   - `${CLAUDE_PLUGIN_ROOT}/CLAUDE.md` → `./CLAUDE.md` (skip if `./CLAUDE.md` already exists — never clobber an existing project memory file)
   - `${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md` → `./MASTER-PROMPT.md`
   - `${CLAUDE_PLUGIN_ROOT}/.env.example` → `./.env.example`
3. `chmod +x` everything under `./scripts/*.sh` and `./.claude/hooks/*.sh`.
4. If `./.claude/settings.json` does not exist yet, copy `${CLAUDE_PLUGIN_ROOT}/.claude/settings.json` to `./.claude/settings.json` so the safety hooks (pre-bash-guard, protect-paths, session-start, post-edit-track, stop-validate-reminder) actually run in this project. If it already exists, leave it alone and tell the human they can merge the `hooks` block from the plugin's `.claude/settings.json` manually if they want the guards.
5. Ensure `./.gitignore` contains (append any missing lines, create the file if absent): `.env`, `.env.*`, `!.env.example`, `.claude/state/`, `/tmp/harness_*`.
6. Seed `./.claude/state/loop.json` only if it does not already exist:
   ```json
   { "iteration": 0, "phase": "idle", "task": null, "validate_attempts": 0, "max_validate_retries": 3, "task_graph": null, "task_complexity": null, "plan_source": null, "review_dispatch": null, "skills_index": null, "skills_assigned": [], "skills_skipped": [], "fanout": null, "iterations_this_run": 0, "max_iterations_per_run": 1, "build_effort_tier": null, "build_effort_score": null, "docs_profile": null }
   ```
7. Run `bash scripts/self-check.sh` (it now exists locally) and report GREEN/issues.

## Do Not

- Do not overwrite any file that already exists in the project — check before every copy.
- Do not run `/master:bootstrap` automatically. Scaffold, report, and stop — bootstrapping is its own step with its own approval.
- Do not touch `.env` (only `.env.example`), and never print secret values.
