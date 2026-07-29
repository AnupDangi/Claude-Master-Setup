# Portable Runs

Agent Master v1.1 replaces the single Claude-specific loop with run-specific, provider-neutral state.

## Lifecycle

```text
start → active → checkpoint → validate → complete
                   ├────────→ handoff → next agent
                   ├────────→ pause → resume
                   └────────→ cancel
```

Every operation is implemented by the `agent-master` CLI. Claude commands, the Codex skill, and Cursor rules call or teach these operations without owning state transitions.

## Start

```bash
agent-master start "add secure authentication" --run auth --agent claude-code
```

The run records:

- Goal and phase
- Creating and last-updating agent
- Branch, base commit, HEAD commit, working-tree cleanliness, and changed files
- File claims and lease
- Decisions and completed tasks
- Commands and validation evidence
- Remaining tasks, blockers, and next action
- Provider-specific optional metadata under `adapter_state`

`.master/active-run` selects the default run. Use `--run` whenever more than one run is active.

## Resume and Verify

```bash
agent-master status --run auth --format json
git status
git branch --show-current
git rev-parse HEAD
```

Status refreshes recorded repository fields from git. The agent must treat repository evidence as authoritative and continue from `next_action`.

`inspect` adds project configuration and run event history:

```bash
agent-master inspect --run auth --format json
```

## Checkpoint

```bash
agent-master checkpoint --run auth --agent codex \
  --phase implementation \
  --completed "Implemented token rotation" \
  --decision "Persist only token hashes" \
  --remaining "Add replay test" \
  --blocker "Awaiting fixture" \
  --next "Create fixture, then run integration tests"
```

Flags may be repeated. Checkpoints should contain facts another agent needs, not chat summaries or personal preferences.

## Validation

Validation commands come from `.master/project.json`. Each check stores:

- Kind: test, build, or runtime
- Exact command
- Exit code
- Start and completion timestamps
- Evidence log reference

The validation record also stores the validated commit, working-tree fingerprint, and command-configuration hash.

GREEN becomes stale when the commit, working tree, required commands, or runtime-check coverage changes. Completion is rejected until validation returns GREEN again.

## Handoff

```bash
agent-master handoff --run auth --agent codex \
  --next "Verify replay protection before completing"
```

Handoff refreshes git state, records the last updater and next action, and releases the run lease. Another provider resumes by reading status and verifying git.

## File Ownership

```bash
agent-master claim --run auth --agent codex src/auth/session.ts
agent-master release --run auth src/auth/session.ts
```

Claims are repository-local and lease-based. Overlapping claims from active runs are rejected unless explicitly forced. This is collision detection, not a distributed scheduler.

## Legacy Claude Loop

`/loop` remains a compatibility alias that starts a universal run. Legacy `.master/state/loop.json`, `handoff.json`, and event history are migrated by `agent-master init`.

Old GREEN state becomes stale because it lacks v1.1 evidence fingerprints. Native Claude subagents, worktrees, and hooks remain optional enhancements.
