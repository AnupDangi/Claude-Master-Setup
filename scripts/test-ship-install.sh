#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
CFG="$(mktemp -d)"
trap 'rm -rf "$TMP" "$CFG"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

mkdir -p "$TMP/sample-checkout/src" "$TMP/sample-checkout/tests"
cd "$TMP/sample-checkout"
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
echo '# stale placeholder' > "$CFG/statusline.sh"
printf '%s\n' '{"statusLine":{"type":"command","command":"python3 statusline.sh"}}' > "$CFG/settings.json"

# Skip network skill install in smoke test (installer still exercises the call path with skip)
MASTER_SKIP_SKILLS=1 node "$ROOT/bin/cli.js" --force --config-dir "$CFG" >/dev/null
test -f "$CFG/claude-master-setup/scripts/install-default-skills.sh" || fail 'install-default-skills.sh not shipped'
test -f "$CFG/claude-master-setup/templates/skills-allowlist.json" || fail 'skills-allowlist.json not shipped'
test -f "$CFG/claude-master-setup/scripts/install-skill.sh" || fail 'install-skill.sh not shipped'
test -f "$CFG/claude-master-setup/scripts/ensure-skills.sh" || fail 'ensure-skills.sh not shipped'

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
for f in COMPANIONS.md scripts/budget-check.sh scripts/loop-event.sh scripts/lease.sh scripts/mcp-catalog.json commands/plan.md agents/docs-writer.md agents/security.md; do
  test ! -e "$PACK/$f" || fail "dead runtime shipped: $f"
done

test -f "$ROOT/.claude/statusline.sh" || fail 'package source missing .claude/statusline.sh'
test -x "$CFG/statusline.sh" || fail 'statusline.sh not installed to config dir'
grep -q 'CLAUDE_PROJECT_DIR' "$CFG/statusline.sh" || fail 'installed statusline missing project-root logic'
! grep -q 'stale placeholder' "$CFG/statusline.sh" || fail 'stale statusline was not replaced'

python3 - "$CFG/settings.json" "$CFG" <<'PY' || fail 'statusLine not wired'
import json, sys
from pathlib import Path
s = json.load(open(sys.argv[1]))
cmd = (s.get("statusLine") or {}).get("command") or ""
assert "statusline.sh" in cmd and "python3" in cmd
assert "CLAUDE_PROJECT_DIR" not in cmd
assert Path(sys.argv[2], "statusline.sh").is_file()
assert ("HARNESS_" + "MAX_ITERATIONS_PER_RUN") not in s.get("env", {})
PY

printf '%s' '{"model":{"display_name":"Test"},"workspace":{"current_dir":"'"$TMP"'/sample-checkout"},"context_window":{"used_percentage":12}}' \
  | CLAUDE_PROJECT_DIR="$TMP/sample-checkout" python3 "$CFG/statusline.sh" \
  | grep -q '📁 sample-checkout' \
  || fail 'statusline did not render project name'

test ! -e "$CFG/commands/plan.md" || fail 'old command survived upgrade'
grep -q 'my custom review command' "$CFG/commands/review.md" || fail 'user command was overwritten'
test ! -e "$CFG/agents/docs-writer.md" || fail 'old agent survived upgrade'
test ! -e "$CFG/skills/capability-orchestrator" || fail 'old skill survived upgrade'

export CLAUDE_PROJECT_DIR="$TMP/sample-checkout" HOME="$TMP/home"
mkdir -p "$HOME"
bash "$PACK/scripts/setup-loop.sh" 'fix tax rounding' >/dev/null
python3 - <<'PY' || fail 'installed loop defaults'
import json
from pathlib import Path
s=json.load(open('.master/state/loop.json'))
proj=json.loads(Path('.master/project.json').read_text())
budget=proj.get('iteration_budget')
expected=budget if isinstance(budget,int) and budget>=1 else 2
assert s['max_iterations']==expected and s['execution_mode']=='direct', (s['max_iterations'], expected, s['execution_mode'])
PY
bash "$PACK/scripts/cancel-loop.sh" >/dev/null
python3 - <<'PY' || fail 'installed cancel'
import json
assert json.load(open('.master/state/loop.json'))['status']=='cancelled'
PY

echo 'Clean install smoke test: OK'
