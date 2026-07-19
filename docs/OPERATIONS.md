# Operations Guide

Three things that don't fit `docs/SETUP.md` (which is about *using* the loop
day to day): maintaining the `npx` package, invoking each of the 11 agents
directly instead of through `/loop`, and how to safely scale work across more
than one agent at a time.

## Part 1 — Managing the `npx` package

### How it works today

`package.json` + `bin/cli.js` (no dependencies, no lifecycle scripts).
`npx claude-master-setup@0.4.0` (or `npx github:AnupDangi/Claude-Master-Setup`
from a tagged/default branch) runs `bin/cli.js`. Both `--global` and `--local`
call the same idempotent `ensureFrameworkInstalled(configDir)`: copies
agents/commands/skills into `configDir` (applying `${CLAUDE_PLUGIN_ROOT}` →
resolved-absolute-path text substitution to every `.md`/`.json` file, mirroring
FORGE Framework's copy-time path-rewrite mechanism — see Decision 007), and
populates `configDir/claude-master-setup/` with the active shared framework
(docs, scripts, hooks, templates). `--local` additionally calls
`seedMasterFolder()`: creates the current project's `.master/state/` +
`.master/docs/` (from `templates/master-docs/`) + `CLAUDE.md` (from
`templates/CLAUDE.md.starter`) — nothing else goes into the project. The
git-clone path (`bash scripts/install.sh`) is for developing the harness
itself, not for starting a new project — it seeds *this* repo's own
`.claude/state/`, unrelated to `.master/`. Current pack is ~104 files
(`npm pack --dry-run`). Works **without** publishing when using the GitHub URL.

### Local development loop

Before changing `bin/cli.js`, verify it still works end to end — including the
shared-framework mechanics, not just that files land somewhere:

```bash
node -c bin/cli.js                                          # syntax check
node bin/cli.js --global --config-dir /tmp/cms-global-test   # shared framework only
grep -L '${CLAUDE_PLUGIN_ROOT}' /tmp/cms-global-test/agents/*.md   # confirm token substitution ran
cd /tmp/some-scratch-dir && HOME=/tmp/cms-local-home node /path/to/bin/cli.js --local
# confirm the scratch project has ONLY .master/ + CLAUDE.md (+.gitignore/.env*) at root
find /tmp/some-scratch-dir -maxdepth 1
# confirm scripts operate on the PROJECT, not the framework location:
CLAUDE_PROJECT_DIR=/tmp/some-scratch-dir bash /tmp/cms-local-home/.claude/claude-master-setup/scripts/validate.sh
```

`--local` doesn't take `--config-dir` (by design — always resolves the shared
framework via `os.homedir()`); redirect it with the `HOME` env var when
testing in a sandbox, never against your real `~/.claude`. This is exactly how
it was verified when built — don't skip the actual run; a syntax-valid script
can still copy the wrong files, skip the token substitution, or seed state
against the wrong directory.

### Versioning discipline

- Bump `version` in `package.json` (SemVer) whenever `bin/cli.js` or the set
  of copied files changes in a way users would notice.
- `npx github:user/repo` always pulls the **current default-branch HEAD** —
  there's no version pinning by default. If you want installs to be
  reproducible, tag releases (`git tag v0.4.0`, push the tag) and tell users
  to install via `npx github:AnupDangi/Claude-Master-Setup#v0.4.0` (append
  `#<tag>`) instead of the bare form.
- Tagging and pushing tags is a real, visible action on the shared repo —
  confirm before pushing, same as any other push.

### Publishing to the npm registry (optional — prepared, not executed)

Nothing about `npx github:...` requires this. Publish only if you want the
shorter `npx claude-master-setup` (no `github:` prefix, and a version can be
pinned the normal npm way, e.g. `npx claude-master-setup@0.4.0`).

**Publish checklist (before every release):**
- ✅ `LICENSE`, `package.json` metadata (`license`, `author`, `keywords`,
  `repository`, `homepage`, `bugs`, `bin`, **`files`**).
- ✅ Explicit `"files"` allowlist; scaffold gitignore is
  `templates/gitignore` (npm **strips** `.gitignore` from installed
  packages even when present in the tarball — never rely on packing
  `.gitignore` alone).
- ✅ `.npmignore` excludes `.claude/state/`, `settings.local.json`, and
  local `test-harness/` so they never ship.
- ✅ `prepack` intentionally runs the full harness self-check for both
  `npm pack` and `npm publish`; `npm test` uses a recursion guard because
  `self-check.sh` normally asks `validate.sh` to invoke the stack test command.
- ✅ `npm pack --dry-run` lists `templates/gitignore` and does **not** list
  `test-harness/`.
- ✅ Fresh scaffold **from outside this repo** (nested dirs inherit this
  package name and break `npx`):  
  `cd /tmp && npx . /tmp/cms-smoke && bash /tmp/cms-smoke/scripts/self-check.sh`  
  Confirm `/tmp/cms-smoke/.gitignore` includes `node_modules/`.

**Publish steps:**
```bash
npm run check:harness
npm test
npm pack --dry-run
npm publish --dry-run --access public
npm whoami                      # must be logged in
git tag v0.4.0                  # after approving the exact commit
git push origin v2-os --tags
npm publish --access public
```

**After publishing:**
- Published versions are **immutable** — bump + publish again for fixes.
- End-user verify:
  ```bash
  npx claude-master-setup@<version> --help
  npx claude-master-setup@<version> --global --config-dir /tmp/claude-smoke
  # expect agents/ + commands/ under that dir
  cd /tmp && mkdir cms-local && cd cms-local
  npx claude-master-setup@<version> --local
  bash scripts/self-check.sh
  ```
- Confirm local install’s `.gitignore` includes `node_modules/` (from `templates/gitignore`).
- Nested installs under this repo’s directory can confuse `npx` (parent package name) — test from `/tmp`.

## Part 2 — Handling all the agents

Two ways any of the 11 agents runs:

1. **Automatic delegation** — Claude Code matches your request against each
   agent's `description` (written as a trigger condition, e.g. "MUST BE USED
   when..."). Asking "review this diff for security issues" auto-routes to
   `security` without you naming it.
2. **Explicit invocation** — name the agent, or use the slash command that
   maps to it.

| Agent | How to invoke it directly | What you get |
|---|---|---|
| `orchestrator` | `/loop` | Runs the full SELECT→...→COMMIT cycle |
| `planner` | `/plan <task>` | A plan only — nothing built |
| `architect` | Auto-pulled in by `orchestrator` for `large`/architecturally significant tasks; or ask explicitly ("have the architect weigh in on X vs Y") | Design challenge + Decision |
| `implementer` | Never directly — only runs inside `/loop`'s BUILD, against an approved plan | Code + tests for the current task |
| `implementer-opus` | Never directly, same reason — the orchestrator picks it automatically when `task_complexity` is `large`. To get it for a specific task, ask the orchestrator to reclassify that task's complexity, not to switch agents | Same job, Opus tier |
| `validator` | `/validate` | GREEN/RED right now, outside the loop |
| `reviewer` | `/review [paths]` | Severity-ranked quality findings |
| `security` | Runs every loop REVIEW; full OWASP pass for auth/input/data/network/secrets/payments/uploads, light pass for pure docs | Severity-ranked security findings |
| `docs-writer` | `/handoff`, or automatic at COMMIT | Synced `PROJECT_STATE.md`/`CHANGELOG.md`/etc. |
| `mcp-scout` | `/mcp-add <tool>` | A checked, consented `.mcp.json` entry |
| `evaluator` | `/evaluate` | The objective-metrics scorecard |

There's deliberately no command to force `implementer-opus` directly — the
whole point of the pair is that the choice is driven by `task_complexity`,
not by you picking a model. If a task needs more capability, say so at PLAN
time so the classification reflects it.

## Part 3 — Building with a swarm of agents

Full capability/parallelism protocol:
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md) (Decision 003).

"Swarm" means three different things here — only some are safe.

### Hierarchical caps (built)

| Parent | Max parallel children | Kind |
|---|---|---|
| Orchestrator | 3 (`HARNESS_MAX_PARALLEL_ORCH`) | Top-level specialists |
| Planner | 3 (`HARNESS_MAX_PARALLEL_PLANNER`) | Read-only research |
| Implementer (parent) | 5 (`HARNESS_MAX_PARALLEL_IMPLEMENTER`) | Writers in **separate worktrees** |
| Evaluator | 3 (`HARNESS_MAX_PARALLEL_EVALUATOR`) | Read-only collectors |

Caps are per parent. Nested children never bypass GATE 2.

### Safe to run in parallel (same worktree)

Anything **read-only** can run side by side:
- Planner's ≤3 research subagents; evaluator's ≤3 collectors.
- `reviewer` + `security` during REVIEW (orchestrator launches both together).
- `/evaluate` in one worktree while `/loop` runs in another — `evaluator`
  never writes.

### Not safe: multi-writer on the same branch

Running multiple `implementer`/`implementer-opus` instances **concurrently
on the same branch** risks conflicting edits, interleaved `validate.sh`, and
broken gates. That remains forbidden.

### Safe parallel writers: worktree fan-out (intra-task)

When GATE 1 approves a file-disjoint `fanout` map, the **parent** implementer
creates ≤5 worktrees via `scripts/worktree-fanout.sh`, runs one child writer
per worktree, merges into the integration branch, then the orchestrator runs
**one** VALIDATE on the merged tree. See
[`CAPABILITY_ORCHESTRATION.md`](CAPABILITY_ORCHESTRATION.md).

### Multi-feature swarm: parallel worktrees + `/loop`

See `docs/DEVELOPMENT_WORKFLOW.md`. Independent roadmap items still scale as
N worktrees, each with its own `/loop`:

```bash
git worktree add ../myproj-payments feat/payments
git worktree add ../myproj-notifications feat/notifications
# one `claude` session per worktree, each running /loop independently
```

### If you want faster iteration

1. Approve a worktree `fanout` when slices are file-disjoint (≤5 writers).
2. Let planner/evaluator use nested research/collectors (≤3 each).
3. Inject local skills via DISCOVER (≤3 per Task).
4. For independent features, use separate `/loop` worktrees — not one branch
   with many writers.

---

## Part 4 — Why a `/loop` can run for an hour (and how to stop it)

This is **not** usually an infinite loop in code. Typical cause:

1. Bootstrap wrote a **fine-grained** roadmap (10–20 items).
2. Human said "complete the end version" / "finish everything".
3. Orchestrator **auto-approved** gates and kept SELECT→COMMIT for every item.
4. Each item costs a full PLAN (often minutes) + BUILD + VALIDATE + REVIEW.
5. Session/API limit kills the agent mid-iteration — no playable demo yet.

Mitigations (built in):

- `/loop` default **`max-iterations=1`** — stop after one COMMIT; run again.
- Raise deliberately: `/loop max-iterations=3`.
- Never treat "finish everything" as skip-GATE permission.
- Bootstrap: coarse milestones for small apps.

See also: `docs/SETUP.md` (day-to-day usage), `docs/AGENTS.md` (full agent
reference), `docs/MODEL_ROUTING.md` (the `implementer`/`implementer-opus`
mechanism), `docs/DEVELOPMENT_WORKFLOW.md` (worktrees in full),
`docs/CAPABILITY_ORCHESTRATION.md` (skills + fan-out).
