# Operations Guide

Three things that don't fit `docs/SETUP.md` (which is about *using* the loop
day to day): maintaining the `npx` package, invoking each of the 11 agents
directly instead of through `/loop`, and how to safely scale work across more
than one agent at a time.

## Part 1 — Managing the `npx` package

### How it works today

`package.json` + `bin/cli.js` (no dependencies). `npx
github:AnupDangi/Claude-Master-Setup [target-dir]` clones the repo fresh into
npx's cache, runs `bin/cli.js`, which copies `.claude/`, `docs/`, `scripts/`,
`CLAUDE.md`, `MASTER-PROMPT.md`, `.env.example` into the target (skipping
anything already there) and then runs `scripts/install.sh` — the same script
a manual git-clone install runs. This works **without publishing to the npm
registry** at all.

### Local development loop

Before changing `bin/cli.js`, verify it still works end to end:

```bash
node -c bin/cli.js                          # syntax check
npx --yes . /tmp/some-scratch-dir            # actually run the scaffold
cd /tmp/some-scratch-dir && bash scripts/self-check.sh   # confirm the result is healthy
```

This is exactly how it was verified when built — don't skip the actual run;
a syntax-valid script can still copy the wrong files or call `install.sh`
with the wrong cwd.

### Versioning discipline

- Bump `version` in `package.json` (SemVer) whenever `bin/cli.js` or the set
  of copied files changes in a way users would notice.
- `npx github:user/repo` always pulls the **current default-branch HEAD** —
  there's no version pinning by default. If you want installs to be
  reproducible, tag releases (`git tag v0.2.0`, push the tag) and tell users
  to install via `npx github:AnupDangi/Claude-Master-Setup#v0.2.0` (append
  `#<tag>`) instead of the bare form.
- Tagging and pushing tags is a real, visible action on the shared repo —
  confirm before pushing, same as any other push.

### Publishing to the npm registry (optional — prepared, not executed)

Nothing about `npx github:...` requires this. Publish only if you want the
shorter `npx claude-master-setup` (no `github:` prefix, and a version can be
pinned the normal npm way, e.g. `npx claude-master-setup@0.2.0`).

**Publish checklist (before every release):**
- ✅ `LICENSE`, `package.json` metadata (`license`, `author`, `keywords`,
  `repository`, `homepage`, `bugs`, `bin`, **`files`**).
- ✅ Explicit `"files"` allowlist so `.gitignore` is always packed (npm’s
  gitignore-fallback omits the `.gitignore` file itself).
- ✅ `.npmignore` excludes `.claude/state/`, `settings.local.json`, and
  local `test-harness/` so they never ship.
- ✅ `npm pack --dry-run` lists `.gitignore` and does **not** list
  `test-harness/`.
- ✅ Fresh scaffold: `npx . /tmp/cms-smoke && bash /tmp/cms-smoke/scripts/self-check.sh`

**Publish steps:**
```bash
npm whoami                      # must be logged in
npm version patch               # or set version in package.json (e.g. 0.1.1)
npm publish                     # add --access public if using a scoped name
```

**After publishing:**
- Published versions are **immutable** — bump + publish again for fixes.
- End-user verify: `npx claude-master-setup@<version> /tmp/fresh && bash /tmp/fresh/scripts/self-check.sh`
- Confirm the fresh install’s `.gitignore` includes `node_modules/` (full
  template from the package), not only the thin patterns `install.sh` appends.

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
| `architect` | Auto-pulled in by `orchestrator` for `large`/architecturally significant tasks; or ask explicitly ("have the architect weigh in on X vs Y") | Design challenge + ADR |
| `implementer` | Never directly — only runs inside `/loop`'s BUILD, against an approved plan | Code + tests for the current task |
| `implementer-opus` | Never directly, same reason — the orchestrator picks it automatically when `task_complexity` is `large`. To get it for a specific task, ask the orchestrator to reclassify that task's complexity, not to switch agents | Same job, Opus tier |
| `validator` | `/validate` | GREEN/RED right now, outside the loop |
| `reviewer` | `/review [paths]` | Severity-ranked quality findings |
| `security` | Auto-added to `/review` when the diff touches auth/input/secrets/payments/uploads; or ask explicitly | Severity-ranked security findings |
| `docs-writer` | `/handoff`, or automatic at COMMIT | Synced `PROJECT_STATE.md`/`CHANGELOG.md`/etc. |
| `mcp-scout` | `/mcp-add <tool>` | A checked, consented `.mcp.json` entry |
| `evaluator` | `/evaluate` | The objective-metrics scorecard |

There's deliberately no command to force `implementer-opus` directly — the
whole point of the pair is that the choice is driven by `task_complexity`,
not by you picking a model. If a task needs more capability, say so at PLAN
time so the classification reflects it.

## Part 3 — Building with a swarm of agents

"Swarm" can mean two different things here, and only one is safe with how
this harness is built.

### Safe to run in parallel

Anything **read-only** can run side by side, because there's no file it
could collide on:
- Multiple research/investigation agents at once (this is how this repo's
  own harness got explored at the start of a session — several read-only
  agents each covering a different area).
- `reviewer` + `security` already run together conceptually during REVIEW.
- `/evaluate` in one worktree while `/loop` runs in another — `evaluator`
  never writes.  

### Not safe, and why this harness doesn't do it

Running multiple `implementer`/`implementer-opus` instances **concurrently
on the same branch**, even on "different" tasks, risks:
- Two agents editing the same file at once → conflicts or silently
  overwritten work.
- Two concurrent `scripts/validate.sh` runs → non-deterministic results,
  interleaved logs.
- Breaking the two-gate model — GATE 1 approves a specific plan; there's no
  meaningful approval for work a second agent is already doing in parallel.

This is exactly why `docs/LOOP.md`'s SELECT step is single-task: one
implementer variant, building one task, gated twice, every time. That
constraint isn't an oversight — it's the thing that makes the gates mean
anything.

### The harness's actual "swarm" pattern: parallel worktrees

See `docs/DEVELOPMENT_WORKFLOW.md`. Each `git worktree` gets its own branch,
its own `orchestrator` running its own `/loop`, and its own auto-memory — so
N independent features build in parallel without ever touching the same
files:

```bash
git worktree add ../myproj-payments feat/payments
git worktree add ../myproj-notifications feat/notifications
# one `claude` session per worktree, each running /loop independently
```

This is the harness's real horizontal scaling: N loops, N branches, N sets of
gates — never N agents racing on one branch.

### If you want faster iteration, not more concurrency

The actual lever is better slicing of the *next* task, not more agents on
the current one: Task Graphs (built — `docs/LOOP_ENGINE.md`) already let
`planner` break an oversized item into an ordered sub-task list under one
approval. The not-yet-built Scheduler would go further and pick which of
several *independent* roadmap items to run next — still one implementer
variant per task, just a smarter choice of which task.

---

See also: `docs/SETUP.md` (day-to-day usage), `docs/AGENTS.md` (full agent
reference), `docs/MODEL_ROUTING.md` (the `implementer`/`implementer-opus`
mechanism), `docs/DEVELOPMENT_WORKFLOW.md` (worktrees in full).
