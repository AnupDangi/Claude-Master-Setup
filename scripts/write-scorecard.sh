#!/usr/bin/env bash
# Persist /evaluate scorecard for SELECT feedback.
# Usage: bash scripts/write-scorecard.sh '<scorecard.json>'
# Or pipe JSON on stdin: ... | bash scripts/write-scorecard.sh --stdin
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT"
mkdir -p .master/state

OUT=".master/state/last_scorecard.json"

if [ "${1:-}" = "--stdin" ]; then
  cat >"$OUT.tmp"
  mv "$OUT.tmp" "$OUT"
else
  PAYLOAD="${1:-}"
  [ -n "$PAYLOAD" ] || { echo "error: scorecard JSON required" >&2; exit 1; }
  printf '%s\n' "$PAYLOAD" >"$OUT"
fi

python3 - "$OUT" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, dict):
    raise SystemExit("scorecard must be a JSON object")
data.setdefault("ts", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"ok": True, "path": str(path)}))
PY

# Also log evaluate event (same scripts/ dir as this file — works from shared framework root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/loop-event.sh" evaluate "{\"path\":\"$OUT\"}" >/dev/null || true
