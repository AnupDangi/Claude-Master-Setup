#!/usr/bin/env bash
# Golden path: setup → validate GREEN → stop-hook completes with handoff.
# Does not require a live Claude session; exercises harness wiring only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/master-golden.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PROJ="$TMP/app"
mkdir -p "$PROJ/src" "$PROJ/tests"
cd "$PROJ"

cat > package.json <<'JSON'
{"name":"golden-cli","scripts":{"test":"node --test","validate":"node -e \"process.exit(0)\""}}
JSON
cat > README.md <<'MD'
# Golden CLI
Tiny fixture for harness golden-path CI.
MD
echo 'module.exports = { ok: true }' > src/index.js
echo "const test = require('node:test'); const assert = require('node:assert'); test('ok', () => assert.equal(1,1));" > tests/index.test.js

# Minimal project.json with iteration_budget and validate_cmd
mkdir -p .master/state .master/docs
cat > .master/project.json <<JSON
{
  "schema_version": 1,
  "name": "golden-cli",
  "maturity": "existing",
  "iteration_budget": 5,
  "stack": {"detected": "Node.js"},
  "validate_cmd": "npm run validate",
  "allow_no_stack": false,
  "docs": {"manifest": [], "load_for_loop": false}
}
JSON

export CLAUDE_PROJECT_DIR="$PROJ"
export CLAUDE_PLUGIN_ROOT="$ROOT"
export MASTER_SKIP_SKILLS=1

# 1) setup-loop should pick iteration_budget=5 when --max-iterations omitted
bash "$ROOT/scripts/setup-loop.sh" "fix typo in golden cli" >/tmp/golden-setup.out
python3 - <<'PY'
import json, os
from pathlib import Path
s = json.loads(Path(os.environ["CLAUDE_PROJECT_DIR"], ".master/state/loop.json").read_text())
assert s["max_iterations"] == 5, f"expected iteration_budget 5, got {s['max_iterations']}"
assert s["active"] is True
assert s["execution_mode"] == "direct"
print("OK setup max_iterations from iteration_budget:", s["max_iterations"])
PY

# 2) validate.sh must be GREEN
bash "$ROOT/scripts/validate.sh" | tee /tmp/golden-validate.out
grep -q "GATE: GREEN" /tmp/golden-validate.out

# Record validator agent (as loop would)
python3 - <<'PY'
import json, os
from pathlib import Path
p = Path(os.environ["CLAUDE_PROJECT_DIR"], ".master/state/loop.json")
s = json.loads(p.read_text())
s["validation"]["status"] = "green"
s["validation"]["agent"] = "validator"
s["ship_completed"] = True
s["phase"] = "complete"
s["assigned_agents"] = []  # direct mode
p.write_text(json.dumps(s, indent=2) + "\n")
print("OK marked GREEN + ship_completed")
PY

# 3) stop-hook with loop-complete should finish
printf '%s\n' '{"message":{"role":"assistant","content":[{"type":"text","text":"<loop-complete/>"}]}}' > "$TMP/transcript.jsonl"
printf '{"transcript_path":"%s"}' "$TMP/transcript.jsonl" | bash "$ROOT/.claude/hooks/loop-stop-hook.sh" | tee /tmp/golden-stop.out

python3 - <<'PY'
import json, os
from pathlib import Path
root = Path(os.environ["CLAUDE_PROJECT_DIR"])
s = json.loads((root / ".master/state/loop.json").read_text())
assert s.get("status") in {"completed", "complete", "done"} or s.get("active") is False, s
handoff = root / ".master/state/handoff.json"
assert handoff.is_file(), "handoff.json missing"
h = json.loads(handoff.read_text())
assert "phase" in h or "status" in h or "prompt" in h
print("OK golden loop completed with handoff")
PY

echo "Golden loop smoke: OK"
