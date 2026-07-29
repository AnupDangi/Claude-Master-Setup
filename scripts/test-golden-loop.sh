#!/usr/bin/env bash
# Golden path for Agent Master v1.1 universal core:
# init-ready fixture → start → validate (trusted) → complete.
# Does not require a live Claude session.
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

mkdir -p .master/docs
cat > .master/project.json <<JSON
{
  "schema_version": 2,
  "name": "golden-cli",
  "maturity": "existing",
  "test_commands": ["npm run test"],
  "sources_of_truth": ["README.md"]
}
JSON

git init -q
git config user.email "agent-master@example.test"
git config user.name "Agent Master Test"
git add -A
git commit -q -m "golden fixture"

export CLAUDE_PROJECT_DIR="$PROJ"
export CLAUDE_PLUGIN_ROOT="$ROOT"
export MASTER_SKIP_SKILLS=1
# This fixture is our own generated project.json, not an untrusted clone —
# skip the validate-command trust gate rather than persisting a fixture-path
# hash (a fresh mktemp dir every run) into the real ~/.claude/agent-master-trust.json.
export AGENT_MASTER_TRUST_PROJECT=1

CLI="$ROOT/bin/cli.js"
RUN_ID="$(node "$CLI" start "fix typo in golden cli" --agent claude-code --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["run_id"])')"
node "$CLI" validate --run "$RUN_ID" --agent claude-code --format json > "$TMP/golden-validate.json"
python3 -c '
import json
r = json.load(open("'"$TMP"'/golden-validate.json"))
assert r["validation"]["status"] == "green", r["validation"]
print("OK universal validate GREEN")
'
node "$CLI" complete --run "$RUN_ID" --agent claude-code --format json > "$TMP/golden-complete.json"
python3 -c '
import json
r = json.load(open("'"$TMP"'/golden-complete.json"))
assert r["status"] == "completed", r
print("OK golden loop completed via universal core")
'

echo "Golden loop smoke: OK"
