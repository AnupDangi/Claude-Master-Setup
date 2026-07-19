#!/usr/bin/env bash
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_FILE="$ROOT/.master/state/loop.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "No loop state found."
  exit 0
fi
python3 - "$STATE_FILE" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
p = Path(sys.argv[1])
try:
    state = json.loads(p.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    p.unlink(missing_ok=True)
    print("Removed corrupt loop state.")
    raise SystemExit(0)
state.update({"active": False, "status": "cancelled", "next_action": None,
              "updated_at": datetime.now(timezone.utc).isoformat()})
p.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
print("Loop cancelled.")
PY
