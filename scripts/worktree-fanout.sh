#!/usr/bin/env bash
# Create / status / merge / cleanup worktrees for adaptive fan-out (≤3 slices).
#
# Safety (production):
# - Requires a git work tree; refuses bare / non-repo cwd
# - Caps slices at 3
# - Validates slice ids + branch names; rejects path traversal in files
# - Constrains worktree_root under the repo's parent directory
# - merge refuses dirty integration tree and in-progress merges
# - file-disjoint ownership enforced before create/merge
#
# Manifest JSON schema:
# {
#   "base_branch": "feat/foo",
#   "worktree_root": "../myproj-fanout",
#   "max_parallel": 3,
#   "slices": [
#     { "id": "a", "title": "...", "branch": "fanout/a", "files": ["src/a.ts"] }
#   ]
# }
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
Usage: bash scripts/worktree-fanout.sh <create|status|merge|cleanup> <manifest.json> [flags]

  create   Add one worktree+branch per slice (max 3, or a lower max_parallel in manifest)
  status   Show worktree paths and whether each branch exists
  merge    Fast-forward each slice into the integration branch when possible;
           otherwise a normal merge (no forced --no-ff). Cleaner history.
  cleanup  Remove fan-out worktrees and delete slice branches (production default).
           Pass --keep-branches to retain slice branches for debugging.

Flags:
  --delete-branches  (cleanup) delete slice branches — default on
  --keep-branches    (cleanup) keep slice branches after removing worktrees

EOF
}

CMD="${1:-}"
MANIFEST="${2:-}"
# Production default: delete fan-out branches on cleanup (cleaner branch list)
DELETE_BRANCHES=1
for arg in "$@"; do
  [ "$arg" = "--keep-branches" ] && DELETE_BRANCHES=0
  [ "$arg" = "--delete-branches" ] && DELETE_BRANCHES=1
done

if [ -z "$CMD" ] || [ "$CMD" = "-h" ] || [ "$CMD" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "$MANIFEST" ] || [ "$MANIFEST" = "--delete-branches" ] || [ "$MANIFEST" = "--keep-branches" ]; then
  echo "error: manifest.json required" >&2
  usage
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "error: manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not inside a git work tree" >&2
  exit 1
fi

MAX_CAP=3

PARSE_OUT="$(python3 - "$MANIFEST" "$REPO_ROOT" "$MAX_CAP" <<'PY'
import json, sys, shlex, re
from pathlib import Path

manifest_path, repo, max_cap = sys.argv[1], Path(sys.argv[2]).resolve(), int(sys.argv[3])
data = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
slices = data.get("slices") or []
if not slices:
    print("error: slices must be a non-empty array", file=sys.stderr)
    sys.exit(1)

max_parallel = min(int(data.get("max_parallel") or max_cap), max_cap)
if len(slices) > max_parallel:
    print(f"error: {len(slices)} slices exceed max_parallel={max_parallel}", file=sys.stderr)
    sys.exit(1)

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
BRANCH_RE = re.compile(r"^(?!/)(?!.*\.\.)[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$")
seen_files = {}
seen_ids = set()
seen_branches = set()

for i, s in enumerate(slices):
    if not isinstance(s, dict):
        print(f"error: slices[{i}] must be an object", file=sys.stderr)
        sys.exit(1)
    sid = s.get("id") or f"s{i}"
    if not ID_RE.match(str(sid)):
        print(f"error: invalid slice id {sid!r} (use [A-Za-z0-9_-], max 64)", file=sys.stderr)
        sys.exit(1)
    if sid in seen_ids:
        print(f"error: duplicate slice id {sid!r}", file=sys.stderr)
        sys.exit(1)
    seen_ids.add(sid)

    branch = s.get("branch") or f"fanout/{sid}"
    if not BRANCH_RE.match(str(branch)) or str(branch).endswith("/"):
        print(f"error: invalid branch name {branch!r}", file=sys.stderr)
        sys.exit(1)
    if branch in seen_branches:
        print(f"error: duplicate branch {branch!r}", file=sys.stderr)
        sys.exit(1)
    seen_branches.add(branch)

    files = s.get("files") or []
    if not isinstance(files, list) or not files:
        print(f"error: slice {sid!r} must list owned files (non-empty)", file=sys.stderr)
        sys.exit(1)
    for f in files:
        if not isinstance(f, str) or not f.strip():
            print(f"error: slice {sid!r} has empty/invalid file path", file=sys.stderr)
            sys.exit(1)
        if f.startswith("/") or f.startswith("~") or ".." in Path(f).parts:
            print(f"error: file path must be repo-relative without '..': {f!r}", file=sys.stderr)
            sys.exit(1)
        if f in seen_files:
            print(
                f"error: file {f!r} owned by both {seen_files[f]!r} and {sid!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        seen_files[f] = sid

# Constrain worktree root to sibling-of-repo (or under repo/.harness-fanout)
raw_root = data.get("worktree_root") or str(repo.parent / f"{repo.name}-fanout")
wt_root = Path(raw_root)
if not wt_root.is_absolute():
    wt_root = (repo / wt_root).resolve()
else:
    wt_root = wt_root.resolve()

allowed_parents = {repo.resolve(), repo.parent.resolve()}
# allow wt_root itself or any path whose parent chain hits allowed
ok = False
probe = wt_root
for _ in range(64):
    if probe in allowed_parents or probe == repo.resolve():
        ok = True
        break
    if probe.parent == probe:
        break
    probe = probe.parent
# Also allow direct child of repo.parent (the default pattern)
if wt_root.parent.resolve() == repo.parent.resolve():
    ok = True
if str(wt_root).startswith(str(repo.resolve() / ".harness-fanout")):
    ok = True
if not ok:
    print(
        f"error: worktree_root {str(wt_root)!r} must be under the repo "
        f"(.harness-fanout/...) or a sibling of the repo",
        file=sys.stderr,
    )
    sys.exit(1)
# Never allow worktrees inside .git
if str(wt_root).startswith(str(repo / ".git")):
    print("error: worktree_root cannot be inside .git", file=sys.stderr)
    sys.exit(1)

base_branch = data.get("base_branch") or ""
if base_branch and not BRANCH_RE.match(str(base_branch)):
    print(f"error: invalid base_branch {base_branch!r}", file=sys.stderr)
    sys.exit(1)

print(f"WT_ROOT={shlex.quote(str(wt_root))}")
print(f"BASE_BRANCH={shlex.quote(str(base_branch))}")
print(f"SLICE_COUNT={len(slices)}")
for i, s in enumerate(slices):
    sid = s.get("id") or f"s{i}"
    branch = s.get("branch") or f"fanout/{sid}"
    title = s.get("title") or sid
    path = str(wt_root / sid)
    print(f"SLICE_{i}_ID={shlex.quote(str(sid))}")
    print(f"SLICE_{i}_BRANCH={shlex.quote(branch)}")
    print(f"SLICE_{i}_TITLE={shlex.quote(str(title))}")
    print(f"SLICE_{i}_PATH={shlex.quote(path)}")
PY
)" || exit 1
eval "$PARSE_OUT"

require_clean_integration() {
  if [ -d "$(git rev-parse --git-path merge)" ] 2>/dev/null || \
     [ -f "$(git rev-parse --git-path MERGE_HEAD)" ]; then
    echo "error: merge already in progress — abort or finish it before fan-out merge" >&2
    exit 1
  fi
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: integration worktree is dirty — commit or stash before merge" >&2
    exit 1
  fi
}

case "$CMD" in
  create)
    mkdir -p "$WT_ROOT"
    if [ -z "$BASE_BRANCH" ]; then
      BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    fi
    if [ "$BASE_BRANCH" = "HEAD" ]; then
      echo "error: detached HEAD — check out an integration branch first" >&2
      exit 1
    fi
    i=0
    while [ "$i" -lt "$SLICE_COUNT" ]; do
      eval "id=\$SLICE_${i}_ID"
      eval "branch=\$SLICE_${i}_BRANCH"
      eval "path=\$SLICE_${i}_PATH"
      if [ -d "$path" ]; then
        echo "  · exists: $path ($branch)"
      else
        if git show-ref --verify --quiet "refs/heads/$branch"; then
          git worktree add "$path" "$branch"
        else
          git worktree add -b "$branch" "$path" "$BASE_BRANCH"
        fi
        echo "  ✓ created $path on $branch"
      fi
      i=$((i + 1))
    done
    RUNTIME="${MANIFEST%.json}.runtime.json"
    python3 - "$MANIFEST" "$RUNTIME" "$WT_ROOT" <<'PY'
import json, sys
from pathlib import Path
manifest, runtime, wt_root = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.loads(Path(manifest).read_text(encoding="utf-8"))
out = {"worktree_root": wt_root, "slices": []}
for s in data.get("slices") or []:
    sid = s.get("id")
    out["slices"].append({
        "id": sid,
        "branch": s.get("branch") or f"fanout/{sid}",
        "path": str(Path(wt_root) / sid),
        "files": s.get("files") or [],
        "title": s.get("title") or sid,
    })
Path(runtime).write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print(f"  ✓ wrote {runtime}")
PY
    ;;

  status)
    i=0
    while [ "$i" -lt "$SLICE_COUNT" ]; do
      eval "id=\$SLICE_${i}_ID"
      eval "branch=\$SLICE_${i}_BRANCH"
      eval "path=\$SLICE_${i}_PATH"
      if [ -d "$path" ]; then
        echo "OK  $id  $branch  $path"
      else
        echo "MISS $id  $branch  $path"
      fi
      i=$((i + 1))
    done
    ;;

  merge)
    require_clean_integration
    i=0
    while [ "$i" -lt "$SLICE_COUNT" ]; do
      eval "id=\$SLICE_${i}_ID"
      eval "branch=\$SLICE_${i}_BRANCH"
      if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        echo "error: slice branch missing: $branch (slice $id)" >&2
        exit 1
      fi
      echo "▶ merging $branch (slice $id)"
      # Prefer fast-forward for linear history; fall back to a normal merge.
      if git merge --ff-only "$branch" 2>/dev/null; then
        echo "  ✓ fast-forwarded $branch"
      elif git merge --no-edit "$branch"; then
        echo "  ✓ merged $branch"
      else
        echo "error: merge conflict on $branch — resolve or: git merge --abort" >&2
        echo "error: escalate to human with conflict paths; do not force GATE 2" >&2
        exit 2
      fi
      i=$((i + 1))
    done
    echo "  ✓ all slice branches merged into $(git rev-parse --abbrev-ref HEAD)"
    ;;

  cleanup)
    i=0
    while [ "$i" -lt "$SLICE_COUNT" ]; do
      eval "id=\$SLICE_${i}_ID"
      eval "branch=\$SLICE_${i}_BRANCH"
      eval "path=\$SLICE_${i}_PATH"
      if [ -d "$path" ]; then
        # Prefer non-force; force only if locked/dirty abandoned tree
        if ! git worktree remove "$path" 2>/dev/null; then
          git worktree remove --force "$path"
        fi
        echo "  ✓ removed worktree $path"
      fi
      if [ "$DELETE_BRANCHES" -eq 1 ]; then
        git branch -D "$branch" 2>/dev/null && echo "  ✓ deleted branch $branch" || true
      fi
      i=$((i + 1))
    done
    git worktree prune 2>/dev/null || true
    RUNTIME="${MANIFEST%.json}.runtime.json"
    rm -f "$RUNTIME"
    ;;

  *)
    echo "error: unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
