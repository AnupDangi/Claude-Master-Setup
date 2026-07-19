#!/usr/bin/env bash
# Cost/budget stop for the AI OS loop.
# Usage: bash scripts/budget-check.sh
# Exit 0 = under budget; exit 3 = STOP (budget exceeded).
#
# Env:
#   HARNESS_MAX_ITERATIONS_PER_RUN   default 1 (from loop.json if set)
#   HARNESS_MAX_COMMITS_PER_DAY      default 20 (loop-logged commits today)
#   HARNESS_MAX_EVENTS_PER_DAY       default 200
#   HARNESS_BUDGET_STOP              default 1 (set 0 to disable hard stop)
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT"

STOP="${HARNESS_BUDGET_STOP:-1}"
MAX_DAY_COMMITS="${HARNESS_MAX_COMMITS_PER_DAY:-20}"
MAX_DAY_EVENTS="${HARNESS_MAX_EVENTS_PER_DAY:-200}"

python3 - "$STOP" "$MAX_DAY_COMMITS" "$MAX_DAY_EVENTS" <<'PY'
import json, sys, os
from datetime import datetime, timezone
from pathlib import Path

stop_on, max_commits, max_events = sys.argv[1] == "1", int(sys.argv[2]), int(sys.argv[3])
today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

loop_path = Path(".master/state/loop.json")
iters = 0
max_iters = int(os.environ.get("HARNESS_MAX_ITERATIONS_PER_RUN", "1") or "1")
if loop_path.is_file():
    try:
        loop = json.loads(loop_path.read_text(encoding="utf-8"))
        iters = int(loop.get("iterations_this_run") or 0)
        if loop.get("max_iterations_per_run") is not None:
            max_iters = int(loop["max_iterations_per_run"])
    except (OSError, json.JSONDecodeError, ValueError):
        pass

log = Path(".master/state/history/events.jsonl")
day_commits = 0
day_events = 0
if log.is_file():
    with log.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = (ev.get("ts") or "")[:10]
            if ts != today:
                continue
            day_events += 1
            if ev.get("type") == "commit":
                day_commits += 1

reasons = []
# Note: iterations_this_run is checked *before* starting another COMMIT cycle;
# orchestrator should call this at SELECT and before BUILD.
if iters >= max_iters and max_iters >= 0:
    reasons.append(f"iterations_this_run {iters} >= max {max_iters}")
if day_commits >= max_commits:
    reasons.append(f"commits_today {day_commits} >= max {max_commits}")
if day_events >= max_events:
    reasons.append(f"events_today {day_events} >= max {max_events}")

out = {
    "ok": len(reasons) == 0,
    "stop": bool(reasons) and stop_on,
    "reasons": reasons,
    "iterations_this_run": iters,
    "max_iterations_per_run": max_iters,
    "commits_today": day_commits,
    "max_commits_per_day": max_commits,
    "events_today": day_events,
    "max_events_per_day": max_events,
}
print(json.dumps(out, ensure_ascii=False))
if reasons and stop_on:
    sys.exit(3)
sys.exit(0)
PY
