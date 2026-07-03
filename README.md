# Claude Master Setup

The last Claude Code setup you'll need before starting any project. Clone it, drop in your requirements docs, and let Claude build the engineering foundation for you.

https://github.com/AnupDangi/Claude-Master-Setup

## New to Claude? Start here

Take these three, in order, before anything else. This is the minimum anyone should know before touching this repo:

1. [Claude 101](https://anthropic.skilljar.com/claude-101)
2. [Claude Code 101](https://anthropic.skilljar.com/claude-code-101)
3. [Claude Code in Action](https://anthropic.skilljar.com/claude-code-in-action)

Everything below is optional, for going deeper — MCP servers, agent skills, subagents — if you want to build and deploy your own applications with Claude Code:

4. [Introduction to Model Context Protocol](https://anthropic.skilljar.com/introduction-to-model-context-protocol)
5. [Model Context Protocol: Advanced Topics](https://anthropic.skilljar.com/model-context-protocol-advanced-topics)
6. [Introduction to Agent Skills](https://anthropic.skilljar.com/introduction-to-agent-skills)
7. [Introduction to Subagents](https://anthropic.skilljar.com/introduction-to-subagents)

Also worth a look: [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) — a curated skills list.

## Install the skill library

Before cloning anything else, install both skill marketplaces. Together they're the reason this setup can move fast — you're not writing skills from scratch, you're pointing Claude at ones that already exist.

### ECC — the harness itself

[ECC](https://github.com/affaan-m/ECC) is 277 skills and 67 subagents (planner, architect, security-reviewer, code-reviewer, tdd-guide, and more) — the agents and hooks this setup relies on.

```
/plugin marketplace add https://github.com/affaan-m/ECC
/plugin install ecc@ecc
```

Or add it directly to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ecc": {
      "source": { "source": "github", "repo": "affaan-m/ECC" }
    }
  }
}
```

### antigravity-awesome-skills — the big library

[antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) is 1,423+ skills covering design, backend, testing, security, infra, product, and marketing — this is the "bunch of skills" library:

```
/plugin marketplace add sickn33/antigravity-awesome-skills
/plugin install antigravity-awesome-skills
```

## What's inside

- **`MASTER-PROMPT.md`** — a bootstrap prompt that turns a PRD + PTR into a full engineering foundation (architecture, `CLAUDE.md`, `docs/`, roadmap, Git strategy)
- **`.claude/settings.json`** — hooks pre-wired (quality gates, permissions) so Claude behaves correctly out of the box
- **`.claude/context/`** — mode profiles (`dev.md`, `research.md`, `review.md`) that switch how Claude works: building, investigating, or reviewing

No platform, no signup, no config wizard. Just files Claude Code already knows how to read.

## Quick start

### 1. Install

```bash
git clone https://github.com/AnupDangi/Claude-Master-Setup.git my-project
cd my-project
claude
```

Claude Code picks up `.claude/settings.json` automatically — hooks and permissions are live, no setup step needed.

### 2. Bootstrap a new project

Add your own requirement docs to the repo:

```
my-project/
├── PRD.md   # Product Requirements Document
├── PTR.md   # Project Technical Requirements
└── ...
```

Then tell Claude:

```
Read MASTER-PROMPT.md and follow it using PRD.md and PTR.md.
```

Claude reads both documents, asks clarifying questions on anything ambiguous, then generates the full foundation — architecture review, `CLAUDE.md`, complete `docs/` folder, Git/branch strategy, implementation roadmap — before writing any implementation code. Nothing starts until you approve the plan.

## Example: switching modes with skills

The context profiles in `.claude/context/` act as lightweight skills — tell Claude which one to use and it adopts that mode for the task:

```
"Use .claude/context/review.md for this PR."
```
→ Claude reviews thoroughly, ranks issues by severity, and suggests fixes instead of just building.

```
"Use .claude/context/dev.md, implement the login form."
```
→ Claude writes code first, runs tests, keeps commits atomic.

```
"Use .claude/context/research.md, figure out why auth is flaky."
```
→ Claude explores first, documents findings, and holds off on code until the cause is clear.

## Example: planning with skills

Once `PRD.md` and `PTR.md` are in the repo, use ECC's planning skill instead of freeform chat:

```
"Use ecc:planner to break PRD.md and PTR.md into an implementation plan."
```
→ Claude reads both docs, proposes an architecture and a build order, and asks clarification questions before any code gets written — same discipline `MASTER-PROMPT.md` enforces.

## Example: UI/UX design with antigravity skills

Once `antigravity-awesome-skills` is installed, invoke its design skills by name and track the work as you go:

```
"Use ui-ux-pro-max to design the dashboard layout — pick a color
palette and font pairing, then explain the choice."
```
→ Claude pulls from the skill's built-in database (50+ styles, 97 palettes, 57 font pairings, 99 UX guidelines) instead of guessing, and gives a reasoned pick, not a random one.

```
"Use antigravity-design-expert for a glassmorphism landing page with
GSAP scroll animation."
```
→ Claude builds the interactive, spatial UI with the motion patterns the skill specifies, instead of a flat static page.

To track multi-step design work instead of losing it in chat scrollback, ask Claude to log it as tasks:

```
"Break the dashboard redesign into tasks and update status as you finish each one."
```
→ Claude creates one task per component, marks each `in_progress`/`completed` as it goes, so progress survives context compaction and long sessions.

## Example: spawning multiple subagents

For independent chunks of work — backend, frontend, tests — spawn subagents in parallel instead of doing each serially:

```
"Spawn three subagents in parallel: one to build the API routes,
one to build the UI, one to write the test suite. Then integrate their output."
```
→ Claude launches each subagent with its own scoped context, waits for all three, then wires the results together. Use this workflow per feature as you build out the product — plan once, fan out the independent pieces, integrate, repeat.

## Code review, three ways

Run one of these before merging, depending on what you actually need checked:

**1. General quality pass** — logic, edge cases, readability, test coverage:
```
"Use .claude/context/review.md and review this PR."
```
→ Severity-ranked findings (critical → low), grouped by file, with suggested fixes.

**2. Security-focused pass** — injection, auth, secrets, unsafe crypto:
```
"Run ecc:security-reviewer on the changes in this PR."
```
→ Flags OWASP Top 10 issues specifically, with fixes suggested, not just findings.

**3. Language-specific pass** — idioms and framework misuse a generic review misses:
```
"Run ecc:python-reviewer on api/" # or react-reviewer, go-reviewer, etc.
```
→ Catches issues specific to the stack (e.g. async/await misuse, hook dependency bugs, ORM N+1 queries) that a general reviewer would skip.

Stack all three on anything touching auth, payments, or user input — cheap insurance before it's in production.

## Built for speed: multiple worktrees

This is a full harness, not a single config file — skills, subagents, hooks, and context modes all wired together so you can build fast and ship fast without waiting on one linear session. The piece that makes that safe: git worktrees.

```
"Start a worktree for the payments feature."
```
→ Claude checks out an isolated copy of the repo on its own branch. Run a second one for a bug fix in parallel — separate working directory, separate branch, zero risk of one session's half-finished edits colliding with another's. Merge each back when it's done.

This is what turns "one task at a time" into "however many independent features you're juggling right now."

## Why MASTER-PROMPT.md matters

Most Claude setups get you a config file. `MASTER-PROMPT.md` gets you an actual engineering foundation, generated once from `PRD.md` + `PTR.md`, before a single line of implementation code exists:

- **Architecture review** — the tech stack and design get challenged (scalability, security, cost, complexity), not accepted as-is
- **Risk assessment** — contradictions, missing requirements, and unrealistic assumptions surface before they become rewrites
- **`CLAUDE.md`** — the permanent memory of the project: conventions, standards, Definition of Done, when Claude should ask instead of assume
- **Full `docs/` set** — `ARCHITECTURE.md`, `DATABASE.md`, `API.md`, `SECURITY.md`, `TESTING.md`, `DEPLOYMENT.md`, and more, all consistent with each other because one process generated them together
- **Git, branch, and worktree strategy** — so parallel work (see above) has a plan behind it, not improvisation
- **Implementation roadmap** — the order to build in, decided before building starts

The point: every future Claude session — yours or a teammate's — starts from a repository that already knows what it is, instead of re-deriving it from a chat history that doesn't exist anymore.

## Why use this

Every other Claude setup asks you to learn a framework first. This one doesn't:

1. Clone the repo.
2. Give Claude your PRD and PTR.
3. Ask it to read `MASTER-PROMPT.md`.

It does the rest.

Drop a 🌟 if if helped.
