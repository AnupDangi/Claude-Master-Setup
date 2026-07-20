#!/usr/bin/env bash
# Install curated agent skills into ~/.claude/skills via the vercel-labs/skills CLI.
# Best-effort: network/CLI failures warn and exit 0 so harness install never fails.
#
# Usage:
#   bash scripts/install-default-skills.sh [path/to/skills-allowlist.json]
#
# Escape hatch (undocumented): MASTER_SKIP_SKILLS=1
set -uo pipefail

if [ "${MASTER_SKIP_SKILLS:-0}" = "1" ]; then
  echo "  skip: MASTER_SKIP_SKILLS=1 — default skills not installed"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOWLIST="${1:-}"

if [ -z "$ALLOWLIST" ]; then
  for candidate in \
    "$PKG_ROOT/templates/skills-allowlist.json" \
    "${CLAUDE_MASTER_ROOT:-}/templates/skills-allowlist.json" \
    "$HOME/.claude/claude-master-setup/templates/skills-allowlist.json"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      ALLOWLIST="$candidate"
      break
    fi
  done
fi

if [ -z "$ALLOWLIST" ] || [ ! -f "$ALLOWLIST" ]; then
  echo "  ! skills allowlist missing — skip default skill install" >&2
  exit 0
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "  ! npx not found — skip default skill install" >&2
  exit 0
fi

# Emit one line per source: source|skill1 skill2 ...
SOURCES_BLOB="$(python3 - "$ALLOWLIST" <<'PY' || true
import json, sys
from pathlib import Path
from collections import OrderedDict
try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except Exception as e:
    print(f"parse_error:{e}", file=sys.stderr)
    raise SystemExit(1)
by_source = OrderedDict()
for block in data.get("installs") or []:
    source = (block.get("source") or "").strip()
    if not source:
        continue
    skills = []
    for skill in block.get("skills") or []:
        skill = str(skill).strip()
        if skill:
            skills.append(skill)
    if not skills:
        continue
    if source not in by_source:
        by_source[source] = []
    for s in skills:
        if s not in by_source[source]:
            by_source[source].append(s)
for source, skills in by_source.items():
    print(source + "|" + " ".join(skills))
PY
)"

if [ -z "$SOURCES_BLOB" ]; then
  echo "  ! empty skills allowlist — skip"
  exit 0
fi

ok_count=0
fail_count=0
LOG_FILE="${TMPDIR:-/tmp}/master-skills-install.log"

while IFS= read -r line; do
  [ -z "$line" ] && continue
  source="${line%%|*}"
  skills_str="${line#*|}"
  set -- $skills_str

  skill_args=()
  for skill in "$@"; do
    skill_args+=(--skill "$skill")
  done

  echo "  → npx skills add $source ($skills_str) → ~/.claude/skills"
  if npx --yes skills add "$source" -g -a claude-code -y --copy "${skill_args[@]}" \
    >"$LOG_FILE" 2>&1; then
    echo "  ✓ installed skills from $source"
    ok_count=$((ok_count + 1))
  else
    echo "  ! skill install failed for $source (harness install continues)" >&2
    echo "    log: $LOG_FILE" >&2
    echo "    retry: npx skills add $source -g -a claude-code -y --copy" >&2
    fail_count=$((fail_count + 1))
  fi
done <<EOF
$SOURCES_BLOB
EOF

if [ "$ok_count" -gt 0 ]; then
  echo "  ✓ default skills ready ($ok_count source(s))"
elif [ "$fail_count" -gt 0 ]; then
  echo "  ! no default skills installed — re-run later when network is available" >&2
fi

exit 0
