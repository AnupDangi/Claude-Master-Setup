#!/usr/bin/env bash
# Runtime skill installer for Claude Code via vercel-labs/skills CLI.
# Best-effort: failures warn and exit 0 unless --strict.
#
# Usage:
#   bash scripts/install-skill.sh <owner/repo> --skill NAME [--skill NAME2]
#   bash scripts/install-skill.sh --list <owner/repo>
#   bash scripts/install-skill.sh --suggest "task query text"
#   bash scripts/install-skill.sh --from-allowlist   # install default installs[]
#
# Always targets: -g -a claude-code -y --copy (global Claude Code skills).
# Escape hatch: MASTER_SKIP_SKILLS=1
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

find_allowlist() {
  for candidate in \
    "$PKG_ROOT/templates/skills-allowlist.json" \
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
STRICT=0
MODE="install"
SOURCE=""
SKILLS=()
QUERY=""
LIST_SOURCE=""

usage() {
  cat <<'EOF'
Usage:
  install-skill.sh <owner/repo> --skill NAME [--skill NAME2 ...]
  install-skill.sh --list <owner/repo>
  install-skill.sh --suggest "<task query>"
  install-skill.sh --from-allowlist
Options:
  --strict     exit 1 on install failure
  -h, --help   show help
EOF
}

if [ "${MASTER_SKIP_SKILLS:-0}" = "1" ]; then
  echo "skip: MASTER_SKIP_SKILLS=1"
  exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --strict) STRICT=1; shift ;;
    --list)
      MODE="list"
      LIST_SOURCE="${2:-}"
      shift 2 || true
      ;;
    --suggest)
      MODE="suggest"
      QUERY="${2:-}"
      shift 2 || true
      ;;
    --from-allowlist)
      MODE="allowlist"
      shift
      ;;
    --skill|-s)
      SKILLS+=("${2:-}")
      shift 2 || true
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [ -z "$SOURCE" ]; then
        SOURCE="$1"
      else
        echo "unexpected arg: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if ! command -v npx >/dev/null 2>&1; then
  echo "! npx not found — cannot install skills" >&2
  [ "$STRICT" = "1" ] && exit 1
  exit 0
fi

validate_source() {
  local s="$1"
  if ! printf '%s' "$s" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    echo "! invalid source (expected owner/repo): $s" >&2
    return 1
  fi
  return 0
}

# Only allow sources present in the allowlist (installs + runtime), unless MASTER_SKILLS_TRUST_ANY=1
source_allowed() {
  local s="$1"
  if [ "${MASTER_SKILLS_TRUST_ANY:-0}" = "1" ]; then
    return 0
  fi
  if [ -z "$ALLOWLIST" ]; then
    # No allowlist → only vercel-labs/agent-skills
    [ "$s" = "vercel-labs/agent-skills" ] && return 0
    return 1
  fi
  python3 - "$ALLOWLIST" "$s" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
want = sys.argv[2]
allowed = set()
for block in data.get("installs") or []:
    src = (block.get("source") or "").strip()
    if src:
        allowed.add(src)
for row in data.get("runtime") or []:
    src = (row.get("source") or "").strip()
    if src:
        allowed.add(src)
raise SystemExit(0 if want in allowed else 1)
PY
}

do_install() {
  local source="$1"
  shift
  local skill_args=()
  local skill
  for skill in "$@"; do
    [ -n "$skill" ] || continue
    skill_args+=(--skill "$skill")
  done
  if [ "${#skill_args[@]}" -eq 0 ]; then
    echo "! at least one --skill is required for install" >&2
    return 1
  fi
  if ! validate_source "$source"; then
    return 1
  fi
  if ! source_allowed "$source"; then
    echo "! source not in skills allowlist: $source" >&2
    echo "  suggest (user-approved): npx skills add $source ${skill_args[*]} -g -a claude-code -y --copy" >&2
    echo "  or set MASTER_SKILLS_TRUST_ANY=1 to allow any owner/repo" >&2
    return 1
  fi

  local log="${TMPDIR:-/tmp}/master-install-skill.log"
  echo "→ npx skills add $source $* → ~/.claude/skills"
  if npx --yes skills add "$source" -g -a claude-code -y --copy "${skill_args[@]}" >"$log" 2>&1; then
    echo "✓ installed: $source ($*)"
    return 0
  fi
  echo "! install failed for $source (see $log)" >&2
  echo "  retry: npx skills add $source ${skill_args[*]} -g -a claude-code -y --copy" >&2
  return 1
}

case "$MODE" in
  list)
    if [ -z "$LIST_SOURCE" ]; then
      echo "Usage: install-skill.sh --list <owner/repo>" >&2
      exit 1
    fi
    if ! validate_source "$LIST_SOURCE"; then
      exit 1
    fi
    npx --yes skills add "$LIST_SOURCE" --list -y 2>/dev/null || {
      echo "! could not list skills for $LIST_SOURCE" >&2
      [ "$STRICT" = "1" ] && exit 1
      exit 0
    }
    ;;
  suggest)
    if [ -z "$QUERY" ] || [ -z "$ALLOWLIST" ]; then
      echo "[]"
      exit 0
    fi
    python3 - "$ALLOWLIST" "$QUERY" <<'PY'
import json, re, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
tokens = {t for t in re.split(r"[^a-z0-9_+-]+", sys.argv[2].lower()) if len(t) >= 3}
out = []
for row in data.get("runtime") or []:
    kws = {str(k).lower() for k in (row.get("keywords") or [])}
    hits = len(tokens & kws)
    if hits <= 0:
        continue
    out.append({
        "source": row.get("source"),
        "skill": row.get("skill"),
        "hits": hits,
        "command": f'npx skills add {row.get("source")} --skill "{row.get("skill")}" -g -a claude-code -y --copy',
    })
out.sort(key=lambda x: x["hits"], reverse=True)
print(json.dumps(out[:5], ensure_ascii=False))
PY
    ;;
  allowlist)
    if [ -z "$ALLOWLIST" ]; then
      echo "! allowlist missing" >&2
      [ "$STRICT" = "1" ] && exit 1
      exit 0
    fi
    bash "$SCRIPT_DIR/install-default-skills.sh" "$ALLOWLIST"
    ;;
  install)
    if [ -z "$SOURCE" ]; then
      usage >&2
      exit 1
    fi
    if [ "${#SKILLS[@]}" -eq 0 ]; then
      echo "! pass at least one --skill NAME" >&2
      exit 1
    fi
    if do_install "$SOURCE" "${SKILLS[@]}"; then
      exit 0
    fi
    [ "$STRICT" = "1" ] && exit 1
    exit 0
    ;;
esac
