#!/usr/bin/env bash
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
echo "── master ──"
if [ -f "$ROOT/.master/state/loop.json" ]; then
  python3 - "$ROOT/.master/state/loop.json" <<'PY' 2>/dev/null || true
import json, sys
from pathlib import Path
try:
    s=json.loads(Path(sys.argv[1]).read_text())
    if s.get("active"):
        print(f"Active loop: {s.get('iteration')}/{s.get('max_iterations')} · {s.get('execution_mode')} · /cancel to stop")
    elif s.get("status") not in {None, "idle"}:
        print(f"Last loop: {s.get('status')}")
except Exception:
    print("Loop state is unreadable; /status for details")
PY
fi
[ -f "$ROOT/CLAUDE.md" ] && echo "Context: CLAUDE.md → .master/project.json → handoff.json"
echo 'Start: /loop "task" (default max 2) · /bootstrap · /status · /pause'
