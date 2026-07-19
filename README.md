# Claude Master Setup

A small Claude Code extension for shipping code through adaptive, validated loops.
It reads the project first, keeps machine state in JSON, and uses extra agents only
when the task benefits from them.

## Install

Plugin:

```bash
claude plugin marketplace add AnupDangi/Claude-Master-Setup
claude plugin install master@claude-master-setup
```

Or install the shared runtime and seed the current project:

```bash
npx claude-master-setup@latest
```

Then open Claude Code in the project and run `/master:bootstrap` once (or
`/bootstrap` with the npm install).

## Commands

- `/bootstrap` — inspect the repository and create minimal project context
- `/loop "task"` — implement and validate; default maximum is 2 iterations
- `/cancel` — stop the active loop
- `/status` — show compact JSON-backed status
- `/pause` — preserve a blocker for another session
- `/handoff` — refresh and summarize cross-session state

Plugin commands are namespaced as `/master:*`.

## Loop examples

```text
/master:loop "fix checkout tax rounding"
/master:loop "add OAuth login" --max-iterations 5
/master:loop "finish migration" --completion-promise "migration is verified"
```

Routing is adaptive:

- simple work runs directly with no subagent;
- medium work delegates one bounded implementation slice;
- complex work gets a dependency graph and at most three independent worktree
  writers with explicit file ownership.

Completion requires the signal to be true and validation to be GREEN. Reaching the
iteration limit stops safely with resumable state; it does not pretend the task is done.

## Project footprint

The installer creates only project-specific `CLAUDE.md`, `.master/project.json`,
`.master/state/loop.json`, and a short optional roadmap. Runtime handoff files stay
under `.master/state/`. It does not create `.env`, `.github`, agent, command, or
framework documentation folders in the project.

## Update

npm users rerun `npx claude-master-setup@latest`. Plugin users update the
`claude-master-setup` marketplace and the `master` plugin; plugins are not assumed
to auto-update immediately.

See [setup](docs/SETUP.md), [loop behavior](docs/LOOP.md), and
[security](docs/SECURITY.md).
