#!/usr/bin/env bash
# Multi-session roadmap item lease (AI OS coordinator).
# Prevents two worktrees/sessions from claiming the same roadmap task.
#
# Usage:
#   bash scripts/lease.sh acquire "<task title>" [owner_id]
#   bash scripts/lease.sh release "<task title>" [owner_id]
#   bash scripts/lease.sh status [task title]
#   bash scripts/lease.sh heartbeat "<task title>" [owner_id]
#
# Leases live in .master/state/leases.json (gitignored). Stale after
# HARNESS_LEASE_TTL_SECONDS (default 7200 = 2h) without heartbeat.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT"

LEASE_FILE=".master/state/leases.json"
mkdir -p .master/state
TTL="${HARNESS_LEASE_TTL_SECONDS:-7200}"
CMD="${1:-}"
TASK="${2:-}"
OWNER="${3:-}"

if [ -z "$OWNER" ]; then
  OWNER="$(hostname -s 2>/dev/null || hostname)_$$"
fi

usage() {
  cat <<'EOF'
Usage:
  bash scripts/lease.sh acquire "<task title>" [owner]
  bash scripts/lease.sh release "<task title>" [owner]
  bash scripts/lease.sh heartbeat "<task title>" [owner]
  bash scripts/lease.sh status [task title]
EOF
}

[ -n "$CMD" ] || { usage; exit 1; }

python3 - "$CMD" "$TASK" "$OWNER" "$LEASE_FILE" "$TTL" <<'PY'
import json, sys, time
from pathlib import Path

cmd, task, owner, lease_path, ttl_s = sys.argv[1], sys.argv[2], sys.argv[3], Path(sys.argv[4]), int(sys.argv[5])
now = int(time.time())

def load():
    if not lease_path.is_file():
        return {"leases": {}}
    try:
        return json.loads(lease_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"leases": {}}

def save(data):
    lease_path.parent.mkdir(parents=True, exist_ok=True)
    lease_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

def purge_stale(data):
    leases = data.get("leases") or {}
    keep = {}
    for k, v in leases.items():
        hb = int(v.get("heartbeat_at") or v.get("acquired_at") or 0)
        if now - hb <= ttl_s:
            keep[k] = v
    data["leases"] = keep
    return data

data = purge_stale(load())
leases = data["leases"]

if cmd == "status":
    if task:
        v = leases.get(task)
        if not v:
            print(json.dumps({"held": False, "task": task}))
        else:
            print(json.dumps({"held": True, "task": task, **v}))
    else:
        print(json.dumps({"leases": leases, "ttl_seconds": ttl_s}, indent=2))
    sys.exit(0)

if not task:
    print("error: task title required", file=sys.stderr)
    sys.exit(1)

if cmd == "acquire":
    cur = leases.get(task)
    if cur and cur.get("owner") != owner:
        print(json.dumps({
            "ok": False,
            "error": "lease_held",
            "task": task,
            "owner": cur.get("owner"),
            "acquired_at": cur.get("acquired_at"),
        }))
        sys.exit(2)
    acquired_at = now
    if cur and cur.get("owner") == owner:
        acquired_at = int(cur.get("acquired_at") or now)
    leases[task] = {
        "owner": owner,
        "acquired_at": acquired_at,
        "heartbeat_at": now,
    }
    save(data)
    print(json.dumps({"ok": True, "task": task, "owner": owner}))
    sys.exit(0)

if cmd == "heartbeat":
    cur = leases.get(task)
    if not cur or cur.get("owner") != owner:
        print(json.dumps({"ok": False, "error": "not_owner"}))
        sys.exit(2)
    cur["heartbeat_at"] = now
    save(data)
    print(json.dumps({"ok": True, "task": task}))
    sys.exit(0)

if cmd == "release":
    cur = leases.get(task)
    if cur and cur.get("owner") not in (owner, None):
        # allow force-release by same owner only
        if cur.get("owner") != owner:
            print(json.dumps({"ok": False, "error": "not_owner", "owner": cur.get("owner")}))
            sys.exit(2)
    leases.pop(task, None)
    save(data)
    print(json.dumps({"ok": True, "released": task}))
    sys.exit(0)

print(f"error: unknown command {cmd}", file=sys.stderr)
sys.exit(1)
PY
