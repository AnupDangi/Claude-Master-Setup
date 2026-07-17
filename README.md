# Claude Master Setup

<img width="2110" height="700" alt="image" src="https://github.com/user-attachments/assets/3727d6e4-4953-424f-9d1b-175a2b7f5532" />

A **self-contained Claude Code harness**. Clone it, drop in your requirements, and it
runs an engineered build loop — plan → build → validate → review → commit — with
specialist subagents and hard quality gates. No plugin marketplace required: it works
with only the files in this repo.

```
/bootstrap   # PRD + PTR  → architecture, CLAUDE.md, docs/, roadmap  (no code yet)
/loop        # runs the build loop until the roadmap is done, gates and all
```

## New to Claude? Start here

Take these three, in order, before anything else:

1. [Claude 101](https://anthropic.skilljar.com/claude-101)
2. [Claude Code 101](https://anthropic.skilljar.com/claude-code-101)
3. [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action)

Going deeper — MCP, skills, subagents:

4. [Introduction to Model Context Protocol](https://anthropic.skilljar.com/introduction-to-model-context-protocol)
5. [Model Context Protocol: Advanced Topics](https://anthropic.skilljar.com/model-context-protocol-advanced-topics)
6. [Introduction to Agent Skills](https://anthropic.skilljar.com/introduction-to-agent-skills)
7. [Introduction to Subagents](https://anthropic.skilljar.com/introduction-to-subagents)

## What's inside

```
CLAUDE.md                 # permanent project memory + how the harness works
MASTER-PROMPT.md          # the /bootstrap prompt: PRD+PTR → engineering foundation
.claude/
├── agents/               # 9 subagents (orchestrator, planner, architect,
│                         #   implementer, validator, reviewer, security,
│                         #   docs-writer, mcp-scout)
├── commands/             # 9 slash commands (/loop, /plan, /validate, /review,
│                         #   /mcp-add, /bootstrap, /handoff, /status, /ship)
├── hooks/                # fail-safe shell hooks (guard, protect, track, remind)
├── context/              # optional mode profiles (dev, review, research)
├── state/                # loop state (gitignored, worktree-local)
└── settings.json         # permissions + hooks — self-contained, no plugin
docs/                     # LOOP, AGENTS, MCP, SETUP + full per-project doc set
scripts/
├── validate.sh           # the gate: format, lint, typecheck, test, build (auto-detected)
├── detect-stack.sh       # stack/package-manager detection
├── install.sh            # one-shot setup
├── self-check.sh         # verify the harness is wired correctly
└── mcp-catalog.json      # curated tool → MCP-server map
```

No signup, no config wizard. Just files Claude Code already knows how to read.

## Quick start

```bash
git clone https://github.com/AnupDangi/Claude-Master-Setup.git my-project
cd my-project
bash scripts/install.sh      # makes scripts/hooks executable, seeds .env & state
claude                       # start Claude Code — hooks & permissions load automatically
bash scripts/self-check.sh   # verify the harness
```

Then add your requirements and bootstrap:

```
my-project/
├── PRD.md   # Product Requirements Document
└── PTR.md   # Project Technical Requirements
```

```
/bootstrap    # generates architecture, CLAUDE.md, docs/, and a build roadmap — no code yet
/loop         # builds the roadmap, one validated increment at a time
```

## Persistent memory & recommended plugins

The harness itself needs nothing beyond this repo, but one plugin closes a real
gap: Claude Code's per-worktree auto-memory forgets everything once a session
ends. **[claude-mem](https://github.com/thedotmack/claude-mem)** makes memory
persistent — it observes your sessions, injects relevant past context
automatically on later ones, and can front-load an entire repo in one pass.

```
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@thedotmack
```

Pair it with the harness like this:

- After `/bootstrap` (or when adopting an existing project), run
  `/learn-codebase` once so claude-mem has full repo context from day one.
- Keep using `docs/PROJECT_STATE.md`, `docs/SESSION.md`, and `docs/DECISIONS.md`
  as the **durable, reviewable** source of truth (per `CLAUDE.md`'s memory
  layers) — claude-mem is a low-friction recall layer on top of those, not a
  replacement for them. If a fact matters to every future session, it still
  belongs in `docs/`, not only in memory.

Two more official plugins complement the loop (optional, no separate
marketplace needed — `claude-plugins-official` ships with Claude Code):

```
/plugin install superpowers@claude-plugins-official   # brainstorming, TDD, systematic debugging
/plugin install code-review@claude-plugins-official    # deeper /code-review ultra pass alongside /review
```

## The build loop

The loop is the product. Full spec in [`docs/LOOP.md`](docs/LOOP.md). It has
been run end-to-end with real subagents against a throwaway project — see
[`docs/VALIDATION.md`](docs/VALIDATION.md) for what was tested and the
honest limitations found.

```
SELECT → PLAN → [approve plan] → BUILD → VALIDATE (hard gate)
       → REVIEW → [approve merge] → COMMIT → update docs → LOOP
```

- **Two human gates** (approve the plan, approve the merge) + **one automated gate**
  (validation). None can be skipped.
- **Validation hard-blocks.** RED means the loop returns to BUILD and will not
  advance. GREEN is binary — no "green with warnings," no skipping a check to pass.
- **One shippable unit per iteration.** New scope goes on the roadmap, not into the
  current task.
- Stop anytime; resume with `/loop`. The **repository** remembers where it was, not
  the chat.

## Subagents

Nine least-privilege specialists in `.claude/agents/` ([reference](docs/AGENTS.md)).
Only `implementer` writes feature code; the reviewers and validator are read-only;
`mcp-scout` only touches `.mcp.json`. Each runs in its own context and returns a
summary, keeping the main thread focused and cheap. Models are matched to the job —
Haiku for docs, Sonnet for building/reviewing, Opus for architecture/security/planning.

## Adding tools (MCP)

When a task needs an external service, run `/mcp-add <tool>`. The **mcp-scout** checks
`scripts/mcp-catalog.json`, then the web, and **asks before** wiring anything into
`.mcp.json` — always with `${ENV_VAR}` references (never literal secrets) and
least-privilege scopes. Details in [`docs/MCP.md`](docs/MCP.md).

```
/mcp-add postgres     # → "add the Postgres MCP server? it needs DATABASE_URL"
```

## Parallel work: git worktrees

Once you're juggling independent features, run each in its own worktree:

```bash
git worktree add ../myproj-payments feat/payments
cd ../myproj-payments && claude    # its own loop, shared docs/, isolated auto-memory
```

Two loops run without colliding. See [`docs/DEVELOPMENT_WORKFLOW.md`](docs/DEVELOPMENT_WORKFLOW.md).

## Installation scope: project, user, or session

Three ways to adopt this, depending on how permanent you want it:

- **Project level (default, what ships here).** `.claude/` lives in the repo
  root, committed and shared with the team. This is the only scope where
  `scripts/validate.sh` makes sense unmodified — it's written against *this*
  project's stack.
- **User level (every project, globally).** Copy `.claude/agents/*.md` and
  `.claude/commands/*.md` into `~/.claude/agents/` and `~/.claude/commands/`
  so the 9 specialists and 9 commands are available no matter which repo you
  open. `scripts/` is still per-project (it runs against that project's real
  build/test commands) — copy it into each project you want the gate in, or
  package the whole harness as a plugin (see Growth path, step 5) so
  installing it anywhere is one command.
- **Session level (try it, install nothing).** Two options: `claude
  --settings .claude/settings.json` from any directory layers in the
  harness's permissions/hooks for that session only; or simplest of all,
  just `cd` into a clone/worktree of this repo and run `claude` there —
  nothing is installed anywhere, it only applies to that directory.

Full detail in [`docs/SETUP.md`](docs/SETUP.md).

## Growth path

Start minimal, add capability only when a real need appears:

1. **Solo, single stream** — `/bootstrap` → `/loop`. A complete workflow on day one.
2. **Add tools** — `/mcp-add` when a task needs a DB, GitHub, or a browser.
3. **Parallelize** — git worktrees for independent features.
4. **Loosen autonomy** — auto-approve GATE 1 for low-risk tasks in a trusted project
   (validation gate always stays on).
5. **Bundle & share** — package your stabilized agents/commands as a Claude Code
   plugin; add stack-specific reviewers as the codebase grows.

Full guide in [`docs/SETUP.md`](docs/SETUP.md).

## Going further (optional)

The harness is complete on its own. If you want a bigger prebuilt skill/agent library
on top, these community marketplaces plug in without changing anything here:

- [ECC](https://github.com/affaan-m/ECC) — 277 skills / 67 subagents.
- [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) — 1,400+ skills.

```
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin install ecc@ecc
```

These are additive. Nothing in this repo depends on them.

---

Drop a 🌟 if it helped you.
