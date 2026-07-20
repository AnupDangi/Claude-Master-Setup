#!/usr/bin/env bash
# Ensure relevant allowlisted skills are present for a task, then re-select top-N.
# Used by setup-loop / bootstrap / loop PLAN when local selection is thin.
#
# Usage:
#   bash scripts/ensure-skills.sh "<task query>" [max]
#
# Prints JSON array of selected skills (same shape as select-skills.sh).
# Best-effort installs from templates/skills-allowlist.json runtime[].
# MASTER_SKIP_SKILLS=1 skips installs (selection still runs).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERY="${1:-}"
MAX="${2:-3}"

if [ -z "$QUERY" ]; then
  echo 'Usage: bash scripts/ensure-skills.sh "<task query>" [max]' >&2
  exit 1
fi

find_allowlist() {
  for candidate in \
    "$SCRIPT_DIR/../templates/skills-allowlist.json" \
    "${CLAUDE_MASTER_ROOT:-}/templates/skills-allowlist.json" \
    "$HOME/.claude/claude-master-setup/templates/skills-allowlist.json"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

ALLOWLIST="$(find_allowlist || true)"
LOCAL_JSON="$(CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" bash "$SCRIPT_DIR/list-local-skills.sh" 2>/dev/null || echo '[]')"
TMP_NEED="$(mktemp)"
trap 'rm -f "$TMP_NEED"' EXIT

python3 - "$ALLOWLIST" "$LOCAL_JSON" "$QUERY" "$TMP_NEED" <<'PY'
import json, re, sys
from pathlib import Path

allow_path, local_raw, query, out_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
needed = []
if allow_path:
    try:
        data = json.loads(Path(allow_path).read_text(encoding="utf-8"))
        local = json.loads(local_raw) if local_raw.strip() else []
        have = {str(s.get("name") or "").lower() for s in local if isinstance(s, dict)}
        tokens = {t for t in re.split(r"[^a-z0-9_+-]+", query.lower()) if len(t) >= 3}
        if tokens:
            for row in data.get("runtime") or []:
                skill = (row.get("skill") or "").strip()
                source = (row.get("source") or "").strip()
                if not skill or not source or skill.lower() in have:
                    continue
                kws = {str(k).lower() for k in (row.get("keywords") or [])}
                hits = len(tokens & kws)
                if hits >= 1:
                    needed.append({"source": source, "skill": skill, "hits": hits})
            needed.sort(key=lambda x: x["hits"], reverse=True)
            needed = needed[:2]
    except Exception:
        needed = []
Path(out_path).write_text(json.dumps(needed), encoding="utf-8")
PY

if [ "${MASTER_SKIP_SKILLS:-0}" != "1" ]; then
  COUNT="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$TMP_NEED" 2>/dev/null || echo 0)"
  if [ "$COUNT" != "0" ]; then
    IDX=0
    while [ "$IDX" -lt "$COUNT" ]; do
      SRC="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[int(sys.argv[2])]["source"])' "$TMP_NEED" "$IDX")"
      SKILL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[int(sys.argv[2])]["skill"])' "$TMP_NEED" "$IDX")"
      echo "ensure-skills: installing $SKILL from $SRC" >&2
      bash "$SCRIPT_DIR/install-skill.sh" "$SRC" --skill "$SKILL" >&2 || true
      IDX=$((IDX + 1))
    done
  fi
fi

CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" bash "$SCRIPT_DIR/select-skills.sh" "$QUERY" "$MAX"
