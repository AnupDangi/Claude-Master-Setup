#!/usr/bin/env bash
# Append-only loop event log (AI OS telemetry).
# Usage:
#   bash scripts/loop-event.sh <event_type> [json_fields_object]
#   bash scripts/loop-event.sh summary
#   bash scripts/loop-event.sh count <event_type>
#
# Events append one JSON line to .master/state/history/events.jsonl (gitignored).
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT"

HIST_DIR=".master/state/history"
LOG="$HIST_DIR/events.jsonl"
mkdir -p "$HIST_DIR"

EVENT="${1:-}"
if [ -z "$EVENT" ] || [ "$EVENT" = "-h" ] || [ "$EVENT" = "--help" ]; then
  cat <<'EOF'
Usage:
  bash scripts/loop-event.sh <event_type> ['{"key":"value"}']
  bash scripts/loop-event.sh summary
  bash scripts/loop-event.sh count <event_type>

Common event_type values:
  select | plan | gate1_approve | gate1_reject | build | validate_green
  validate_red | await_human_on_red | review | gate2_approve | gate2_reject
  commit | evaluate | lease_acquire | lease_release | budget_stop | skill_skip
EOF
  exit 0
fi

if [ "$EVENT" = "summary" ]; then
  if [ ! -f "$LOG" ]; then
    echo '{"total":0,"by_type":{},"manual_interventions":0,"loop_commits":0}'
    exit 0
  fi
  python3 - "$LOG" <<'PY'
import json, sys
from collections import Counter
path = sys.argv[1]
types = Counter()
manual = 0
commits = 0
total = 0
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        total += 1
        t = ev.get("type", "unknown")
        types[t] += 1
        if t in ("await_human_on_red", "gate1_reject", "gate2_reject"):
            manual += 1
        if t == "commit":
            commits += 1
print(json.dumps({
    "total": total,
    "by_type": dict(types),
    "manual_interventions": manual,
    "loop_commits": commits,
}, ensure_ascii=False))
PY
  exit 0
fi

if [ "$EVENT" = "count" ]; then
  TYPE="${2:-}"
  [ -n "$TYPE" ] || { echo "error: count needs event_type" >&2; exit 1; }
  if [ ! -f "$LOG" ]; then
    echo 0
    exit 0
  fi
  python3 - "$LOG" "$TYPE" <<'PY'
import json, sys
path, want = sys.argv[1], sys.argv[2]
n = 0
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == want:
            n += 1
print(n)
PY
  exit 0
fi

# Quote default as "{}" — bare ${2:-{}} appends a literal "}" when $2 is set.
EXTRA="${2:-"{}"}"
python3 - "$LOG" "$EVENT" "$EXTRA" <<'PY'
import json, sys, os
from datetime import datetime, timezone
from pathlib import Path

log, event, extra_s = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    extra = json.loads(extra_s) if extra_s.strip() else {}
except json.JSONDecodeError:
    print("error: fields must be valid JSON object", file=sys.stderr)
    sys.exit(1)
if not isinstance(extra, dict):
    print("error: fields must be a JSON object", file=sys.stderr)
    sys.exit(1)

# Load loop.json snapshot fields if present
loop_path = Path(".master/state/loop.json")
loop_bits = {}
if loop_path.is_file():
    try:
        loop = json.loads(loop_path.read_text(encoding="utf-8"))
        for k in ("iteration", "phase", "task", "task_complexity", "validate_attempts"):
            if k in loop:
                loop_bits[k] = loop[k]
    except (OSError, json.JSONDecodeError):
        pass

rec = {
    "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "type": event,
    "cwd": os.getcwd(),
    **loop_bits,
    **extra,
}
with open(log, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
print(json.dumps({"ok": True, "type": event, "log": log}, ensure_ascii=False))
PY
