#!/usr/bin/env bash
# Rank local skills for a task query; print top-N JSON objects.
# Usage:
#   bash scripts/select-skills.sh "task text..." [max]
#   bash scripts/list-local-skills.sh | bash scripts/select-skills.sh --stdin "task text..." [max]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

FROM_STDIN=0
if [ "${1:-}" = "--stdin" ]; then
  FROM_STDIN=1
  shift
fi

QUERY="${1:-}"
MAX="${2:-3}"

if [ -z "$QUERY" ]; then
  echo 'Usage: bash scripts/select-skills.sh [--stdin] "<task query>" [max]' >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [ "$FROM_STDIN" -eq 1 ]; then
  cat >"$TMP"
else
  bash "$SCRIPT_DIR/list-local-skills.sh" >"$TMP"
fi

python3 - "$TMP" "$QUERY" "$MAX" <<'PY'
import json, re, sys
from pathlib import Path

index_path, query, max_s = sys.argv[1], sys.argv[2].lower(), max(0, int(sys.argv[3]))
skills = json.loads(Path(index_path).read_text(encoding="utf-8"))

tokens = [t for t in re.split(r"[^a-z0-9_+-]+", query) if len(t) >= 3]
if not tokens or max_s == 0:
    print("[]")
    raise SystemExit(0)

# Penalize plugin skills when query is UI/design/3D/frontend related
UI_TOKENS = {"ui", "design", "three", "react", "frontend", "3d", "css", "vue", "svelte", "tailwind", "figma"}
query_has_ui = bool(UI_TOKENS & set(tokens))

prio = {"project": 3, "user": 2, "plugin": 1}
scored = []
for s in skills:
    blob = f"{s.get('name', '')} {s.get('description', '')}".lower()
    score = sum(1 for t in tokens if t in blob)
    if score <= 0:
        continue
    source = s.get("source", "plugin")
    base_prio = prio.get(source, 0)
    # Penalize plugin skills on UI queries unless they are UI-specific
    if query_has_ui and source == "plugin":
        skill_is_ui = any(ut in blob for ut in UI_TOKENS)
        if not skill_is_ui:
            base_prio = max(0, base_prio - 2)
    scored.append((score, base_prio, s))

scored.sort(key=lambda x: (x[0], x[1]), reverse=True)
out = []
for score, _, s in scored:
    name = (s.get("name") or "").lower()
    if score >= 2 or any(t in name for t in tokens):
        out.append(s)
    if len(out) >= max_s:
        break

print(json.dumps(out, ensure_ascii=False))
PY
