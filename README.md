# Claude Master Setup

[![npm version](https://img.shields.io/npm/v/claude-master-setup?style=for-the-badge&logo=npm&logoColor=white&color=CB3837)](https://www.npmjs.com/package/claude-master-setup)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)
[![GitHub](https://img.shields.io/badge/github-AnupDangi%2FClaude--Master--Setup-181717?style=for-the-badge&logo=github)](https://github.com/AnupDangi/Claude-Master-Setup)

**Engineering OS for Claude Code** — a repeatable loop (plan → build → validate → review → commit) with specialist subagents and hard quality gates. Your app stays clean: only `CLAUDE.md` + `.master/`.

## Recommended: plugin (5 minutes)

```bash
# 1) Install the plugin once (Claude Code)
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup

# 2) In your app repo
cd ~/code/my-app
# add PRD.md and PTR.md (product + technical requirements)

claude   # start Claude Code in this repo
```

Then run:

```text
/master:init        # creates .master/ + CLAUDE.md (once)
/master:bootstrap   # reads PRD/PTR → fills .master/docs + roadmap (no feature code)
/master:loop        # one shippable unit: plan → build → validate → review → commit
/master:status      # where the loop is
/master:handoff     # end of session
```

### What your app looks like after `/master:init`

```text
my-app/
├── PRD.md
├── PTR.md
├── CLAUDE.md                 # stable conventions (commit)
└── .master/
    ├── docs/                 # PROJECT_STATE, ROADMAP, DECISIONS, … (commit)
    └── state/                # loop.json, leases, events (gitignored)
```

The plugin supplies agents, commands, hooks, and scripts from Claude Code’s plugin
cache (machine-level `.claude` / plugin root — **not** copied into your app).

### Worked example

```bash
mkdir -p ~/tmp/demo-harness && cd ~/tmp/demo-harness
git init
# Write a short PRD.md and PTR.md describing a tiny Node CLI
claude
# → /master:init
# → /master:bootstrap   (approve the foundation)
# → /master:loop        (approve plan, then merge)
```

## Alternate: npm installer

Same project footprint; commands are **unprefixed** (`/loop` instead of `/master:loop`).

```bash
cd ~/code/my-app
npx claude-master-setup          # wires Claude config + seeds .master/ here
claude
# → /bootstrap → /loop → /status → /handoff
```

| Flag | Meaning |
|---|---|
| *(default)* | Shared framework + seed current project |
| `--framework-only` | Framework only (no project seed) |
| `--global` / `--local` | Thin aliases (compat) |

> **Pick one path per machine:** plugin **or** npm. Both at once double-fires hooks.

## How machine `.claude` and project `.master` work together

| Layer | Where | Role |
|---|---|---|
| Plugin / user Claude config | Machine | Agents, `/master:*` commands, hooks, scripts |
| `.master/docs/` | Your repo | Project memory (roadmap, decisions, narrative) |
| `.master/state/` | Your repo (gitignored) | Loop machine state |
| `CLAUDE.md` | Your repo | Stable rules the loop always reads first |

`templates/master-docs/` in **this** GitHub repo are blank stubs copied into `.master/docs/` on init — not a second docs system for your app.

## Local skills

On `/master:loop`, the orchestrator discovers local `SKILL.md` files from:

1. `./.claude/skills/` (optional project skills)
2. User `~/.claude/skills/`
3. Installed Claude Code plugins

Top ≤3 relevant skills are injected into Tasks. No web search for skills mid-loop.

## Commands

| Plugin | npm | Purpose |
|---|---|---|
| `/master:init` | `/init` | Seed `.master/` + `CLAUDE.md` |
| `/master:bootstrap` | `/bootstrap` | Foundation from PRD/PTR (no feature code) |
| `/master:loop` | `/loop` | One iteration of the build loop |
| `/master:plan` | `/plan` | Plan only |
| `/master:validate` | `/validate` | Validation gate |
| `/master:review` | `/review` | Quality + security review |
| `/master:status` | `/status` | Phase + project state |
| `/master:handoff` | `/handoff` | Session handoff |
| `/master:evaluate` | `/evaluate` | Objective scorecard |
| `/master:mcp-add` | `/mcp-add` | Add MCP server (with consent) |

## Why it exists

```text
Without:  Prompt → Code → Prompt → Code …
With:     Goal → Plan → [approve] → Build → Validate → Review → [approve] → Commit
```

Two human gates + one hard validate gate + reviewer/security every iteration.
Stop anytime; resume with `/master:status` then `/master:loop` — **disk** remembers.

## Uninstall

1. Uninstall the plugin via Claude Code plugin UI / `claude plugin uninstall master@claude-master-setup`.
2. If you used npm: remove the shared `claude-master-setup` folder under your Claude config and the `harness:*` hooks / `HARNESS_FRAMEWORK_ROOT` env entry from `settings.json`.
3. In the project: delete `CLAUDE.md` and `.master/`.

## Troubleshooting

- **Missing `.master/`** → run `/master:init` first (before bootstrap).
- **`validate.sh` not found** → lives in the plugin/framework root, not your app.
- **Permission prompts on scripts** → allow shared `*/scripts/*.sh` once.
- **Resume after crash** → `/master:status` then `/master:loop`.
- Full guide: [`docs/SETUP.md`](docs/SETUP.md).

## For harness developers (this GitHub repo)

Cloning **this** repository is for developing the harness itself — not for starting a product.

```bash
git clone https://github.com/AnupDangi/Claude-Master-Setup.git
cd Claude-Master-Setup
bash scripts/install.sh    # contributor setup
npm test
```

See [`docs/OPERATIONS.md`](docs/OPERATIONS.md).

## Publish (maintainers)

Branch: **`v2-os`**. Version: **0.4.0**.

```bash
bash scripts/self-check.sh
# npm publish only when you intentionally release
```

---

Drop a star if it helped you.
