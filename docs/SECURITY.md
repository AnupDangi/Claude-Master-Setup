# Security

Agent Master stores repository-local task state and command evidence. It does not make autonomous coding inherently safe.

## State and Evidence

- `.master/runs/`, `events/`, `evidence/`, `locks/`, and `active-run` are gitignored.
- Validation output may contain paths, test data, or accidental secrets. Review logs before sharing them.
- `.env`, `.env.*`, private keys, and common secret paths are excluded by project and Claude-provider guards.
- Stable `.master/project.json`, docs, and thin adapters may be committed.

## Repository Evidence

Status refreshes branch, HEAD, dirty state, and changed files from git. Recorded handoff state never overrides current repository evidence.

Validation is bound to:

- The validated commit
- A working-tree fingerprint
- The configured validation-command hash
- Required runtime-check execution

Completion fails when evidence is missing, RED, or stale.

`.master/project.json` is repo-committed, so its `test_commands`, `build_command`,
and `runtime_check` can be edited by anyone with write access to the repo —
including a clone of an untrusted repo or a peer agent. `agent-master validate`
runs them locally with your privileges, so the first time a project's exact
command set is seen on a machine, validate refuses to run and prints the
commands for review. Re-run with `--trust` to approve that exact command set
on this machine (the approval is keyed to a hash of the commands and stored in
`~/.claude/agent-master-trust.json`, not in the repo); any later edit to the
commands requires trusting again. CI can set `AGENT_MASTER_TRUST_PROJECT=1` to
skip the prompt for a pipeline that already reviews the commit before running.

## Concurrency

Run files are written atomically under short process locks. File claims use repository-local leases and reject active ownership conflicts. This prevents common same-checkout collisions but is not a distributed lock across clones or machines.

## Native Providers

Provider integrations do not copy native memories, credentials, or chat history into `.master/`. Claude hooks are optional enhancements; the universal core (init/start/checkpoint/validate/handoff) does not ship or require any Claude subagents.

Provider sandboxes, approvals, tool permissions, and service authentication still apply. Review provider configuration before enabling hooks, skills, plugins, or non-interactive execution.

## Publishing

The package allowlist excludes `.env`, local runtime state, `.github`, caches, and generated user data. Always inspect `npm pack --dry-run` before publishing both the primary and compatibility packages.

Report vulnerabilities privately to the repository maintainer rather than opening a public exploit issue.

## Hooks

- `notify-stop.sh` never `eval`s model- or state-derived strings into the shell; desktop
  notifications are invoked from Python with list-form `subprocess` arguments.
- `session-start.sh` and `notify-stop.sh` accept only safe `active-run` IDs
  (`[a-zA-Z0-9._-]{1,64}`) and refuse path escape outside `.master/runs/`.

