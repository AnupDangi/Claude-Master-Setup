#!/usr/bin/env bash
# Maturity-gated doc sync: scans repo for evidence and writes/updates docs stubs.
# Only runs for maturity=existing or production. Does NOT overwrite non-stub content.
# Updates project.json docs.manifest with discovered doc paths.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
DOCS_DIR="$REPO_ROOT/.master/docs"
PROJECT_JSON="$REPO_ROOT/.master/project.json"

log() { printf '  sync-docs: %s\n' "$1"; }
skip() { printf '  sync-docs: skip %s (%s)\n' "$1" "$2"; }

# Check maturity gate
MATURITY="$(python3 - "$PROJECT_JSON" <<'PY'
import json, sys
from pathlib import Path
try:
    p = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    print(p.get("maturity", "new"))
except Exception:
    print("new")
PY
)"

if [[ "$MATURITY" == "new" || "$MATURITY" == "prototype" ]]; then
  skip "all docs" "maturity=$MATURITY (only syncs for existing/production)"
  exit 0
fi

mkdir -p "$DOCS_DIR"

MANIFEST=()

# API.md — scan for route definitions
if python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
import re
root = Path(sys.argv[1])
patterns = [
    re.compile(r"(app|router)\.(get|post|put|patch|delete)\s*\(", re.MULTILINE),
    re.compile(r"@(Get|Post|Put|Patch|Delete)\(", re.MULTILINE),
    re.compile(r"path\s*=\s*['\"]\/"),
]
found = False
for p in root.rglob("*"):
    if not p.is_file() or any(x in str(p) for x in ["node_modules",".git","dist","build"]):
        continue
    if p.suffix not in {".js",".ts",".py",".go",".java",".rb",".php"}:
        continue
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
        if any(pat.search(text) for pat in patterns):
            found = True
            break
    except OSError:
        pass
raise SystemExit(0 if found else 1)
PY
then
  if [[ ! -f "$DOCS_DIR/API.md" ]] || grep -q "^# API Reference" "$DOCS_DIR/API.md" 2>/dev/null; then
    if [[ ! -f "$DOCS_DIR/API.md" ]]; then
      cat > "$DOCS_DIR/API.md" << 'STUB'
# API Reference

Auto-generated stub. Update this file when routes are added or changed.

## Endpoints

<!-- Add endpoint documentation here -->
STUB
      log "created API.md stub"
    fi
    MANIFEST+=("API.md")
  else
    log "API.md exists with custom content — not overwriting"
    MANIFEST+=("API.md")
  fi
fi

# DATABASE.md — scan for schema/migration evidence
if python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
import re
root = Path(sys.argv[1])
indicators = ["migrations", "schema.sql", "schema.prisma", "models.py",
              "entity.ts", "migration.ts", "knexfile", "sequelize", "drizzle"]
found = False
for p in root.rglob("*"):
    if not p.is_file() or any(x in str(p) for x in ["node_modules",".git"]):
        continue
    if any(ind in str(p).lower() for ind in indicators):
        found = True
        break
    if p.suffix in {".sql"} and p.stat().st_size > 0:
        found = True
        break
raise SystemExit(0 if found else 1)
PY
then
  if [[ ! -f "$DOCS_DIR/DATABASE.md" ]]; then
    cat > "$DOCS_DIR/DATABASE.md" << 'STUB'
# Database

Auto-generated stub. Update when schema or migrations change.

## Schema

<!-- Document tables/models here -->

## Migrations

<!-- Document migration history here -->
STUB
    log "created DATABASE.md stub"
  fi
  MANIFEST+=("DATABASE.md")
fi

# DEPLOYMENT.md — scan for deployment config
if python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
indicators = ["Dockerfile","docker-compose","Procfile",".railway","vercel.json",
              "fly.toml","render.yaml","heroku.yml","kubernetes","k8s"]
found = any(
    any(ind.lower() in str(p).lower() for ind in indicators)
    for p in root.rglob("*")
    if p.is_file() and ".git" not in str(p) and "node_modules" not in str(p)
)
raise SystemExit(0 if found else 1)
PY
then
  if [[ ! -f "$DOCS_DIR/DEPLOYMENT.md" ]]; then
    cat > "$DOCS_DIR/DEPLOYMENT.md" << 'STUB'
# Deployment

Auto-generated stub. Update when deployment configuration changes.

## Environments

<!-- Document environments here -->

## Deploy steps

<!-- Document deployment process here -->
STUB
    log "created DEPLOYMENT.md stub"
  fi
  MANIFEST+=("DEPLOYMENT.md")
fi

# SECURITY.md — scan for auth/payment evidence
if python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
import re
root = Path(sys.argv[1])
keywords = ["auth","jwt","oauth","passport","bcrypt","stripe","payment","session","csrf"]
found = False
for p in root.rglob("*"):
    if not p.is_file() or any(x in str(p) for x in ["node_modules",".git","dist"]):
        continue
    if p.suffix not in {".js",".ts",".py",".go",".java",".rb"}:
        continue
    try:
        text = p.read_text(encoding="utf-8", errors="ignore").lower()
        if any(kw in text for kw in keywords):
            found = True
            break
    except OSError:
        pass
raise SystemExit(0 if found else 1)
PY
then
  if [[ ! -f "$DOCS_DIR/SECURITY.md" ]]; then
    cat > "$DOCS_DIR/SECURITY.md" << 'STUB'
# Security

Auto-generated stub. Update when auth or sensitive features change.

## Authentication

<!-- Document auth mechanism -->

## Authorization

<!-- Document permission model -->

## Sensitive data handling

<!-- Document PII/secrets handling -->
STUB
    log "created SECURITY.md stub"
  fi
  MANIFEST+=("SECURITY.md")
fi

# TESTING.md — scan for test config
if python3 - "$REPO_ROOT" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
indicators = ["jest.config","vitest.config","pytest.ini","setup.cfg",
              ".mocharc","cypress.config","playwright.config"]
found = any(
    any(ind in p.name.lower() for ind in indicators)
    for p in root.rglob("*")
    if p.is_file() and ".git" not in str(p) and "node_modules" not in str(p)
)
raise SystemExit(0 if found else 1)
PY
then
  if [[ ! -f "$DOCS_DIR/TESTING.md" ]]; then
    cat > "$DOCS_DIR/TESTING.md" << 'STUB'
# Testing

Auto-generated stub. Update when test strategy or coverage changes.

## Test commands

<!-- Document how to run tests -->

## Test coverage

<!-- Document coverage targets -->
STUB
    log "created TESTING.md stub"
  fi
  MANIFEST+=("TESTING.md")
fi

# Update project.json docs.manifest
if [[ -f "$PROJECT_JSON" && ${#MANIFEST[@]} -gt 0 ]]; then
  python3 - "$PROJECT_JSON" "${MANIFEST[@]}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
docs = list(sys.argv[2:])
try:
    state = json.loads(p.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    state = {}
if "docs" not in state or not isinstance(state["docs"], dict):
    state["docs"] = {}
state["docs"]["manifest"] = docs
state["docs"]["load_for_loop"] = False
p.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
PY
  log "updated project.json docs.manifest: ${MANIFEST[*]}"
fi

log "sync complete (maturity=$MATURITY)"
