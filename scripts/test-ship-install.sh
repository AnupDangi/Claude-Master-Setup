#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
CFG="$(mktemp -d)"
trap 'rm -rf "$TMP" "$CFG"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

mkdir -p "$TMP/app/src" "$TMP/app/tests"
cd "$TMP/app"
git init -q
cat > package.json <<'JSON'
{"name":"sample-checkout","scripts":{"test":"node --test","build":"node -c src/index.js"}}
JSON
cat > README.md <<'MD'
# Sample Checkout

Calculates checkout totals for a small storefront.
MD
echo 'module.exports = {}' > src/index.js
echo '' > tests/index.test.js

# Simulate an upgrade from the old, larger install surface.
mkdir -p "$CFG/commands" "$CFG/agents" "$CFG/skills/capability-orchestrator"
echo '${CLAUDE_PLUGIN_ROOT} legacy master command' > "$CFG/commands/plan.md"
echo 'my custom review command' > "$CFG/commands/review.md"
echo 'Claude Master Setup legacy agent' > "$CFG/agents/docs-writer.md"
echo 'name: capability-orchestrator' > "$CFG/skills/capability-orchestrator/SKILL.md"
echo '# reads .master/state' > "$CFG/statusline.sh"
printf '%s\n' '{"statusLine":{"type":"command","command":"python3 statusline.sh"}}' > "$CFG/settings.json"

node "$ROOT/bin/cli.js" --force --config-dir "$CFG" >/dev/null

test -f CLAUDE.md || fail 'CLAUDE.md missing'
test -f .master/project.json || fail 'project.json missing'
test -f .master/state/loop.json || fail 'loop.json missing'
test -f .master/docs/ROADMAP.md || fail 'roadmap missing'
grep -q 'sample-checkout' CLAUDE.md || fail 'project name not inferred'
grep -q 'Calculates checkout totals' CLAUDE.md || fail 'mission not inferred'
! grep -qi 'AI OS\|subagent table\|harness architecture' CLAUDE.md || fail 'harness prose leaked'
python3 - <<'PY' || fail 'project metadata'
import json
p=json.load(open('.master/project.json'))
assert p['name']=='sample-checkout'
assert p['maturity'] in {'existing','production'}
assert p['stack']['detected'].startswith('Node.js')
PY

test ! -e .env || fail '.env created'
test ! -e .github || fail '.github created'
test ! -e .claude || fail '.claude copied into project'

PACK="$CFG/claude-master-setup"
for f in scripts/setup-loop.sh scripts/cancel-loop.sh scripts/classify-task.py scripts/write-handoff.py hooks/loop-stop-hook.sh; do
  test -f "$PACK/$f" || fail "shared runtime missing $f"
done
for f in COMPANIONS.md statusline.sh scripts/budget-check.sh scripts/loop-event.sh scripts/lease.sh scripts/mcp-catalog.json commands/plan.md agents/docs-writer.md agents/security.md; do
  test ! -e "$PACK/$f" || fail "dead runtime shipped: $f"
done
test ! -e "$CFG/commands/plan.md" || fail 'old command survived upgrade'
grep -q 'my custom review command' "$CFG/commands/review.md" || fail 'user command was overwritten'
test ! -e "$CFG/agents/docs-writer.md" || fail 'old agent survived upgrade'
test ! -e "$CFG/skills/capability-orchestrator" || fail 'old skill survived upgrade'
test ! -e "$CFG/statusline.sh" || fail 'old statusline survived upgrade'
python3 - "$CFG/settings.json" <<'PY' || fail 'clean settings upgrade'
import json,sys
s=json.load(open(sys.argv[1]))
assert 'statusLine' not in s
assert 'extraKnownMarketplaces' not in s
assert ('HARNESS_' + 'MAX_ITERATIONS_PER_RUN') not in s.get('env', {})
PY

export CLAUDE_PROJECT_DIR="$TMP/app" HOME="$TMP/home"
mkdir -p "$HOME"
bash "$PACK/scripts/setup-loop.sh" 'fix tax rounding' >/dev/null
python3 - <<'PY' || fail 'installed loop defaults'
import json
s=json.load(open('.master/state/loop.json'))
assert s['max_iterations']==2 and s['execution_mode']=='direct'
PY
bash "$PACK/scripts/cancel-loop.sh" >/dev/null
python3 - <<'PY' || fail 'installed cancel'
import json
assert json.load(open('.master/state/loop.json'))['status']=='cancelled'
PY

echo 'Clean install smoke test: OK'
