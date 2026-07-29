#!/usr/bin/env bash
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
echo "── Agent Master ──"

if [ -f "$ROOT/.master/active-run" ]; then
  python3 - "$ROOT/.master" <<'PY' 2>/dev/null || true
import json, re, sys
from pathlib import Path

RUN_ID_RE = re.compile(r"^[a-zA-Z0-9._-]{1,64}$")
master = Path(sys.argv[1]).resolve()
run_id = (master / "active-run").read_text(encoding="utf-8").strip()
if not RUN_ID_RE.match(run_id):
    print("Run: (invalid active-run id — ignored)")
    raise SystemExit(0)
runs_dir = (master / "runs").resolve()
run_path = (runs_dir / f"{run_id}.json").resolve()
try:
    run_path.relative_to(runs_dir)
except ValueError:
    print("Run: (active-run path escape — ignored)")
    raise SystemExit(0)
state = json.loads(run_path.read_text(encoding="utf-8"))
validation = (state.get("validation") or {}).get("status", "not_run")
print(f"Run: {run_id} · {state.get('status')} · {state.get('phase')} · validation {validation}")
print(f"Next: {state.get('next_action') or '(none)'}")
PY
elif [ -f "$ROOT/.master/state/loop.json" ]; then
  echo "Legacy state found. Run: agent-master init"
fi

[ -f "$ROOT/AGENTS.md" ] && echo "Context: AGENTS.md → .master/project.json → agent-master status"
echo 'Commands: /master:start · /master:status · /master:checkpoint · /master:validate · /master:handoff'
