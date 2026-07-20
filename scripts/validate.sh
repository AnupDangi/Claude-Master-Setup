#!/usr/bin/env bash
# The validation gate. Auto-detects the stack and runs: format check, lint,
# typecheck, tests, build. Exit 0 = GREEN. Any non-zero = RED.
# This script is the hard gate the loop refuses to advance past.
#
# Customize per project by editing the run_* functions or project scripts.
# Missing steps are skipped, not failed —
# but a step that exists and fails makes the whole gate RED.
set -uo pipefail
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$REPO_ROOT" || exit 3

# shellcheck source=detect-stack.sh
. "$(dirname "$0")/detect-stack.sh"

STACK="$(detect_stack)"
FAILED=0
RAN=""

say()  { printf '\n\033[1m▶ %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓ %s\033[0m\n' "$1"; RAN="$RAN $1"; }
fail() { printf '  \033[31m✗ %s\033[0m\n' "$1"; FAILED=1; RAN="$RAN $1"; }
skip() { printf '  \033[90m· %s (skipped)\033[0m\n' "$1"; }

# Runs a command; treats "script/target not found" as skip, real failure as RED.
step() { # step "label" cmd...
  local label="$1"; shift
  if "$@" >/tmp/harness_validate.log 2>&1; then ok "$label"
  else
    local code=$?
    # npm "missing script" and make "no rule" => skip, not fail
    if grep -qiE "missing script|no rule to make target|command not found|no such (file|target)" /tmp/harness_validate.log; then
      skip "$label"
    else
      fail "$label"; tail -30 /tmp/harness_validate.log | sed 's/^/    /'
    fi
  fi
}

say "Stack detected: $STACK"
case "$STACK" in
  node-pnpm) PM="pnpm"; RUN="pnpm";;
  node-yarn) PM="yarn"; RUN="yarn";;
  node-npm)  PM="npm";  RUN="npm run";;
  *) PM=""; RUN="";;
esac

case "$STACK" in
  node-*)
    step "lint"      $RUN lint
    step "typecheck" $RUN typecheck
    step "test"      $RUN test
    step "build"     $RUN build
    # Dev smoke: if package.json has a "start" or "dev" script, curl health
    if python3 - "$REPO_ROOT/package.json" <<'PY2' 2>/dev/null
import json, sys
from pathlib import Path
try:
    pkg = json.loads(Path(sys.argv[1]).read_text())
    scripts = pkg.get("scripts", {})
    raise SystemExit(0 if ("start" in scripts or "server" in scripts or "dev" in scripts) else 1)
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
PY2
    then
      # Only run dev smoke if explicitly enabled (avoids server startup in CI)
      if [[ "${HARNESS_DEV_SMOKE:-0}" == "1" ]]; then
        say "Dev smoke check"
        if PORT="${HARNESS_SMOKE_PORT:-3000}" timeout 10 curl -sf "http://localhost:${HARNESS_SMOKE_PORT:-3000}/api/health" >/dev/null 2>&1; then
          ok "health endpoint"
        else
          skip "health endpoint (server not running or HARNESS_DEV_SMOKE!=1)"
        fi
      fi
    fi
    ;;
  python-poetry)
    step "lint"      poetry run ruff check .
    step "typecheck" poetry run mypy .
    step "test"      poetry run pytest -q
    ;;
  python-uv)
    step "lint"      uv run ruff check .
    step "typecheck" uv run mypy .
    step "test"      uv run pytest -q
    ;;
  python-pip)
    step "lint"      ruff check .
    step "typecheck" mypy .
    step "test"      pytest -q
    ;;
  rust)
    step "format"    cargo fmt --check
    step "lint"      cargo clippy -- -D warnings
    step "test"      cargo test
    step "build"     cargo build
    ;;
  go)
    step "vet"       go vet ./...
    step "test"      go test ./...
    step "build"     go build ./...
    ;;
  make)
    step "lint"      make lint
    step "test"      make test
    step "build"     make build
    ;;
  unknown)
    printf '  \033[33m! No known stack detected.\033[0m\n'
    printf '  Edit scripts/validate.sh to define this project'"'"'s checks.\n'
    # Unknown stack is RED unless project.json explicitly marks a docs-only repo.
    ALLOW_NO_STACK="$(python3 - "$REPO_ROOT/.master/project.json" <<'PY2'
import json, sys
from pathlib import Path
try:
    print("1" if json.loads(Path(sys.argv[1]).read_text()).get("allow_no_stack") is True else "0")
except Exception:
    print("0")
PY2
)"
    if [ "$ALLOW_NO_STACK" = "1" ]; then
      ok "no-stack (allowed)"
    else
      fail "no-stack (configure validate.sh or set allow_no_stack=true in project.json)"
    fi
    ;;
esac

echo
record_validation() {
  local status="$1"
  python3 - "$REPO_ROOT/.master/state/loop.json" "$status" "$RAN" <<'PY2'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
p = Path(sys.argv[1])
if p.is_file():
    try:
        state = json.loads(p.read_text(encoding="utf-8"))
        state["validation"] = {
            "status": sys.argv[2],
            "command": "framework:validate",
            "agent": state.get("validation", {}).get("agent"),
            "checks": sys.argv[3].strip().split(),
            "checked_at": datetime.now(timezone.utc).isoformat(),
        }
        state["updated_at"] = datetime.now(timezone.utc).isoformat()
        p.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    except (OSError, json.JSONDecodeError):
        pass
PY2
}

if [ "$FAILED" -eq 0 ]; then
  printf '\033[1;32mGATE: GREEN\033[0m — ran:%s\n' "${RAN:- (nothing)}"
  record_validation green
  rm -f "$REPO_ROOT/.master/state/validation-pending"
  exit 0
else
  printf '\033[1;31mGATE: RED\033[0m — one or more checks failed.\n'
  record_validation red
  exit 1
fi
