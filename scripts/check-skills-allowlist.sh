#!/usr/bin/env bash
# Validate skills-allowlist.json names against the checked-in --list snapshot.
# Catches upstream renames (e.g. react-best-practices → vercel-react-best-practices).
#
# Usage:
#   bash scripts/check-skills-allowlist.sh
# Exit 0 = OK, 1 = mismatch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOW="$PKG_ROOT/templates/skills-allowlist.json"
SNAP="$PKG_ROOT/templates/skills-list-snapshot.json"

[ -f "$ALLOW" ] || { echo "missing $ALLOW" >&2; exit 1; }
[ -f "$SNAP" ] || { echo "missing $SNAP" >&2; exit 1; }

python3 - "$ALLOW" "$SNAP" <<'PY'
import json, sys
from pathlib import Path

allow = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
snap = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
known = {str(s).strip() for s in (snap.get("skills") or []) if str(s).strip()}
if not known:
    print("snapshot skills[] is empty", file=sys.stderr)
    raise SystemExit(1)

needed = set()
for block in allow.get("installs") or []:
    for s in block.get("skills") or []:
        needed.add(str(s).strip())
for row in allow.get("runtime") or []:
    s = (row.get("skill") or "").strip()
    if s:
        needed.add(s)
# catalog keys that look like skill names should also be covered when they match installs/runtime
for key in (allow.get("catalog") or {}):
    if key in needed:
        pass  # already tracked
    # do not require every catalog alias key — only installs+runtime

missing = sorted(s for s in needed if s and s not in known)
if missing:
    print("Allowlist skill names missing from skills-list-snapshot.json:", file=sys.stderr)
    for s in missing:
        print(f"  - {s}", file=sys.stderr)
    print(
        "Refresh snapshot: npx skills add vercel-labs/agent-skills --list",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"OK: {len(needed)} allowlist skill name(s) ⊆ snapshot ({len(known)} known)")
PY
