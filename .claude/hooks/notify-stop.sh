#!/usr/bin/env bash
# Optional desktop notification for terminal Agent Master states.
# Never pipe Python stdout into a shell evaluator — that was an injection vector.
set -euo pipefail

[[ "${MASTER_DESKTOP_NOTIFY:-1}" == "0" ]] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-.}"
ACTIVE="$ROOT/.master/active-run"
[[ -f "$ACTIVE" ]] || exit 0

# Drain Stop-hook stdin so the host is not left waiting on a pipe.
cat >/dev/null 2>&1 || true

python3 - "$ROOT/.master" <<'PY'
import json
import platform
import re
import subprocess
import sys
from pathlib import Path

RUN_ID_RE = re.compile(r"^[a-zA-Z0-9._-]{1,64}$")

def as_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

master = Path(sys.argv[1]).resolve()
try:
    run_id = (master / "active-run").read_text(encoding="utf-8").strip()
except OSError:
    raise SystemExit(0)

if not RUN_ID_RE.match(run_id):
    raise SystemExit(0)

runs_dir = (master / "runs").resolve()
run_path = (runs_dir / f"{run_id}.json").resolve()
try:
    run_path.relative_to(runs_dir)
except ValueError:
    raise SystemExit(0)

try:
    state = json.loads(run_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(0)

status = str(state.get("status") or "")
validation = str((state.get("validation") or {}).get("status") or "not_run")
project = master.parent.name
goal = str(state.get("goal") or run_id).replace("\n", " ").replace("\r", " ")[:90]

messages = {
    "completed": ("Agent Master · Done", f"{goal} · validation {validation}"),
    "paused": ("Agent Master · Needs you", str((state.get("blockers") or ["Paused"])[0])[:120]),
    "handoff": ("Agent Master · Handoff ready", str(state.get("next_action") or goal)[:120]),
    "cancelled": ("Agent Master · Cancelled", goal),
}
if status not in messages and validation not in {"red", "stale"}:
    raise SystemExit(0)

title, body = messages.get(status, (f"Agent Master · Validation {validation}", goal))
title = f"{title} — {project}"
body = str(body).replace("\n", " ").replace("\r", " ")

if platform.system() != "Darwin":
    raise SystemExit(0)
if not any(Path(p).exists() for p in ("/usr/bin/osascript", "/bin/osascript")):
    raise SystemExit(0)

script = f"display notification {as_quote(body)} with title {as_quote(title)}"
subprocess.run(["osascript", "-e", script], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY
