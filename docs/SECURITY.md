# Security

The extension reduces risk with narrow project output, explicit package allowlists,
shell guards, protected control-plane files, isolated parallel writers, and binary
validation.

## Boundaries

- `.env`, `.env.*`, common secret paths, and private keys are denied to read tools.
- Dangerous shell patterns and piped remote installers are blocked by the Bash hook.
- Framework hooks, commands, agents, settings, and validation are protected from
  accidental edits. The maintainer override is explicit and local.
- `git push`, GitHub CLI, Docker, and web fetches require user confirmation in shipped
  settings.
- The package and project installer exclude `.env`, `.github`, local state, worktrees,
  and maintainer-only files.

## Parallel work

Parallel writers require a valid git repository, sanitized slice/branch names,
file-disjoint ownership, worktrees below the repository parent, and a hard maximum of
three slices. Integration refuses a dirty tree and never force-merges conflicts.

## Validation and review

A completion signal is ignored unless the stored validation result is GREEN. Important
or security-sensitive changes should receive the combined reviewer pass for access
control, injection, secrets, network/file input, data exposure, dependencies,
correctness, and test coverage.

No guard makes autonomous code inherently safe. Review permissions and diffs before
shipping sensitive changes, and report vulnerabilities privately to the repository
maintainer rather than opening a public exploit issue.
