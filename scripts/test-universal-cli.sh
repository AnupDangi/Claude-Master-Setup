#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/bin/cli.js"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agent-master-v11.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Test fixtures are our own generated project.json files, not an untrusted
# clone — skip the validate-command trust gate rather than polluting the
# real ~/.claude/agent-master-trust.json with fixture hashes via --trust.
export AGENT_MASTER_TRUST_PROJECT=1

fail() {
  echo "FAIL universal CLI: $*" >&2
  exit 1
}

new_repo() {
  local dir="$1"
  mkdir -p "$dir/src"
  cat > "$dir/package.json" <<'JSON'
{
  "name": "fixture-project",
  "version": "1.0.0",
  "scripts": {
    "test": "node -e \"process.stdout.write('tests ok')\"",
    "build": "node -e \"process.stdout.write('build ok')\""
  }
}
JSON
  printf '%s\n' 'module.exports = 1;' > "$dir/src/index.js"
  git -C "$dir" init -q
  git -C "$dir" config user.email "agent-master@example.test"
  git -C "$dir" config user.name "Agent Master Test"
  git -C "$dir" add .
  git -C "$dir" commit -qm "fixture"
}

MAIN="$TMP_ROOT/main"
new_repo "$MAIN"

(cd "$MAIN" && node "$CLI" init >/dev/null)
python3 - "$MAIN" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
project = json.loads((root / ".master/project.json").read_text())
assert project["schema_version"] == 2
assert project["test_commands"] == ["npm run test"]
assert project["build_command"] == "npm run build"
for rel in ["AGENTS.md", "CLAUDE.md", ".cursor/rules/master-protocol.mdc"]:
    assert (root / rel).is_file(), rel
gitignore = (root / ".gitignore").read_text()
for pattern in [".master/active-run", ".master/runs/", ".master/events/", ".master/evidence/", ".master/locks/"]:
    assert pattern in gitignore, pattern
PY

(cd "$MAIN" && node "$CLI" start "Implement authentication" --run auth --agent claude-code >/dev/null)
(cd "$MAIN" && node "$CLI" checkpoint --run auth --agent codex \
  --completed "Added token parser" \
  --decision "Use rotating refresh tokens" \
  --remaining "Add replay test" \
  --next "Implement replay test" >/dev/null)
(cd "$MAIN" && node "$CLI" handoff --run auth --agent codex --next "Run auth tests" >/dev/null)

(cd "$MAIN" && node "$CLI" status --run auth --format json) > "$TMP_ROOT/auth.json"
(cd "$MAIN" && node "$CLI" inspect --run auth --format json) > "$TMP_ROOT/auth-inspect.json"
python3 - "$TMP_ROOT/auth.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["goal"] == "Implement authentication"
assert s["status"] == "handoff"
assert s["last_updated_by"]["agent"] == "codex"
assert s["completed_tasks"][0]["text"] == "Added token parser"
assert s["decisions"][0]["text"] == "Use rotating refresh tokens"
assert s["remaining_tasks"] == ["Add replay test"]
assert s["next_action"] == "Run auth tests"
assert s["repository"]["branch"]
PY
python3 - "$TMP_ROOT/auth-inspect.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["project"]["schema_version"] == 2
assert s["verification"]["repository_evidence_wins"] is True
assert any(event["type"] == "checkpoint" for event in s["events"])
assert any(event["type"] == "handoff" for event in s["events"])
PY

# All ordered adapter pairs can exchange a run through shared state.
pairs=(
  "claude-code codex"
  "codex claude-code"
  "claude-code cursor"
  "cursor claude-code"
  "codex cursor"
  "cursor codex"
)
pair_index=0
for pair in "${pairs[@]}"; do
  pair_index=$((pair_index + 1))
  from="${pair%% *}"
  to="${pair##* }"
  run="pair-$pair_index"
  (cd "$MAIN" && node "$CLI" start "Cross-agent pair $pair_index" --run "$run" --agent "$from" >/dev/null)
  (cd "$MAIN" && node "$CLI" handoff --run "$run" --agent "$from" --next "Continue pair $pair_index" >/dev/null)
  (cd "$MAIN" && node "$CLI" checkpoint --run "$run" --agent "$to" --completed "Resumed pair $pair_index" >/dev/null)
  (cd "$MAIN" && node "$CLI" validate --run "$run" --agent "$to" >/dev/null)
  (cd "$MAIN" && node "$CLI" complete --run "$run" --agent "$to" >/dev/null)
  (cd "$MAIN" && node "$CLI" status --run "$run" --format json) > "$TMP_ROOT/$run.json"
  python3 - "$TMP_ROOT/$run.json" "$to" "$pair_index" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["last_updated_by"]["agent"] == sys.argv[2]
assert s["completed_tasks"][-1]["text"] == f"Resumed pair {sys.argv[3]}"
assert s["status"] == "completed"
assert s["validation"]["status"] == "green"
PY
done

# Separate claims succeed; overlapping live claims fail.
(cd "$MAIN" && node "$CLI" claim --run auth --agent codex src/index.js >/dev/null)
(cd "$MAIN" && node "$CLI" start "Checkout work" --run checkout --agent cursor >/dev/null)
printf '%s\n' 'module.exports = 2;' > "$MAIN/src/checkout.js"
(cd "$MAIN" && node "$CLI" claim --run checkout --agent cursor src/checkout.js >/dev/null)
if (cd "$MAIN" && node "$CLI" claim --run checkout --agent cursor src/index.js >/dev/null 2>&1); then
  fail "overlapping file claim was accepted"
fi

# An expired lease no longer blocks another run.
python3 - "$MAIN/.master/runs/auth.json" <<'PY'
import json, sys
from pathlib import Path
file = Path(sys.argv[1])
run = json.loads(file.read_text())
run["ownership"]["lease_expires_at"] = "2000-01-01T00:00:00.000Z"
file.write_text(json.dumps(run, indent=2) + "\n")
PY
(cd "$MAIN" && node "$CLI" claim --run checkout --agent cursor src/index.js >/dev/null)

# Current evidence permits completion.
(cd "$MAIN" && node "$CLI" start "Validated work" --run valid --agent claude-code >/dev/null)
(cd "$MAIN" && node "$CLI" validate --run valid --agent claude-code >/dev/null)
(cd "$MAIN" && node "$CLI" complete --run valid --agent claude-code >/dev/null)

# Any post-validation source change makes evidence stale and blocks completion.
(cd "$MAIN" && node "$CLI" start "Staleness check" --run stale --agent codex >/dev/null)
(cd "$MAIN" && node "$CLI" validate --run stale --agent codex >/dev/null)
printf '%s\n' 'module.exports = 3;' > "$MAIN/src/index.js"
(cd "$MAIN" && node "$CLI" status --run stale --format json) > "$TMP_ROOT/stale.json"
python3 - "$TMP_ROOT/stale.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["validation"]["status"] == "stale"
assert "working_tree_changed" in s["validation"]["stale_reasons"]
assert s["repository"]["working_tree_clean"] is False
assert "src/index.js" in s["repository"]["changed_files"]
PY
if (cd "$MAIN" && node "$CLI" complete --run stale --agent cursor >/dev/null 2>&1); then
  fail "completion accepted stale validation"
fi

# Validation configuration drift is stale, and a newly required runtime check
# cannot be treated as if it had already run.
CONFIG="$TMP_ROOT/config-drift"
new_repo "$CONFIG"
(cd "$CONFIG" && node "$CLI" init >/dev/null)
(cd "$CONFIG" && node "$CLI" start "Validation config drift" --run config --agent codex >/dev/null)
(cd "$CONFIG" && node "$CLI" validate --run config --agent codex >/dev/null)
python3 - "$CONFIG/.master/project.json" <<'PY'
import json, sys
from pathlib import Path
file = Path(sys.argv[1])
project = json.loads(file.read_text())
project["runtime_check"] = "node -e \"process.exit(0)\""
file.write_text(json.dumps(project, indent=2) + "\n")
PY
(cd "$CONFIG" && node "$CLI" status --run config --format json) > "$TMP_ROOT/config-stale.json"
python3 - "$TMP_ROOT/config-stale.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["validation"]["status"] == "stale"
assert "validation_commands_changed" in s["validation"]["stale_reasons"]
assert "runtime_check_missing" in s["validation"]["stale_reasons"]
PY

# Legacy loop and handoff state migrate without losing portable fields.
LEGACY="$TMP_ROOT/legacy"
new_repo "$LEGACY"
mkdir -p "$LEGACY/.master/state/history"
cat > "$LEGACY/.master/state/loop.json" <<'JSON'
{
  "schema_version": 1,
  "active": true,
  "status": "running",
  "prompt": "Migrate authentication",
  "phase": "build",
  "iteration": 2,
  "max_iterations": 5,
  "assigned_agents": ["implementer"],
  "correction_log": [{"at": "2026-01-01T00:00:00Z", "prompt": "Keep API compatible"}],
  "validation": {"status": "green", "checks": ["test"]},
  "next_action": "Finish integration tests"
}
JSON
cat > "$LEGACY/.master/state/handoff.json" <<'JSON'
{
  "task": "Migrate authentication",
  "status": "paused",
  "phase": "build",
  "branch": "main",
  "commit": "legacy-head",
  "working_tree_clean": false,
  "remaining_tasks": ["Integration test"],
  "blockers": ["Awaiting fixture"],
  "next_prompt": "Add the fixture",
  "updated_by": "claude-code"
}
JSON
printf '%s\n' '{"type":"legacy_checkpoint","at":"2026-01-01T00:00:00Z"}' > "$LEGACY/.master/state/history/events.jsonl"
(cd "$LEGACY" && node "$CLI" init >/dev/null)
(cd "$LEGACY" && node "$CLI" status --format json) > "$TMP_ROOT/migrated.json"
python3 - "$TMP_ROOT/migrated.json" "$LEGACY" <<'PY'
import json, sys
from pathlib import Path
s = json.load(open(sys.argv[1]))
root = Path(sys.argv[2])
assert s["goal"] == "Migrate authentication"
assert s["status"] == "paused"
assert s["remaining_tasks"] == ["Integration test"]
assert s["blockers"] == ["Awaiting fixture"]
assert s["next_action"] == "Add the fixture"
assert s["validation"]["status"] == "stale"
assert "legacy_evidence_missing" in s["validation"]["stale_reasons"]
assert s["adapter_state"]["claude-code"]["iteration"] == 2
events = (root / ".master/events/events.jsonl").read_text()
assert "legacy_migrated" in events
assert "legacy:legacy_checkpoint" in events
PY

(cd "$MAIN" && node "$CLI" doctor --format json) > "$TMP_ROOT/doctor.json"
python3 - "$TMP_ROOT/doctor.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["healthy"], d
assert all(d["providers"].keys())
PY

(cd "$MAIN" && node "$CLI" pack list --format json) > "$TMP_ROOT/packs.json"
python3 - "$TMP_ROOT/packs.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["installed"] == []
assert d["available"][0]["name"] == "graph-engineering"
assert d["available"][0]["status"] == "planned"
PY

CODEX_HOME="$TMP_ROOT/codex-home" node "$CLI" install codex >/dev/null
test -f "$TMP_ROOT/codex-home/skills/agent-master/SKILL.md" \
  || fail "Codex skill installer did not install the Agent Master skill"

# Regression: .claude/commands/*.md pass the whole $ARGUMENTS as ONE quoted
# shell token (required so a decision/note can never break out via `;`, `|`,
# `$(...)`) — parseCli must still recover the individual --flag values from
# that single blob, or every multi-flag command (checkpoint, pause, etc.)
# breaks the moment it's driven through the real command templates.
BLOB_RUN="$(cd "$MAIN" && node "$CLI" start "blob arg test" --agent claude-code --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["run_id"])')"
BLOB_ARGS="--run $BLOB_RUN --decision \"chose approach X\" --completed \"wrote the fix\" --next \"ship it\""
(cd "$MAIN" && node "$CLI" checkpoint "$BLOB_ARGS" --agent claude-code --format json) > "$TMP_ROOT/blob-checkpoint.json"
python3 - "$TMP_ROOT/blob-checkpoint.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["decisions"][-1]["text"] == "chose approach X", d["decisions"]
assert d["completed_tasks"][-1]["text"] == "wrote the fix", d["completed_tasks"]
assert d["next_action"] == "ship it", d["next_action"]
print("OK quoted-blob checkpoint parses multiple flags")
PY

echo "OK universal Agent Master CLI"
