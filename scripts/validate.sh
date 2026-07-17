#!/usr/bin/env bash
# The validation gate. Auto-detects the stack and runs: format check, lint,
# typecheck, tests, build. Exit 0 = GREEN. Any non-zero = RED.
# This script is the hard gate the loop refuses to advance past.
#
# Customize per project by editing the run_* functions or setting the
# HARNESS_* env vars below. Missing steps are skipped, not failed —
# but a step that exists and fails makes the whole gate RED.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

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
    # Unknown stack is RED so the gate is never silently open on a real project.
    # If this is intentional (e.g. docs-only repo), export HARNESS_ALLOW_NO_STACK=1.
    if [ "${HARNESS_ALLOW_NO_STACK:-0}" = "1" ]; then
      ok "no-stack (allowed)"
    else
      fail "no-stack (set HARNESS_ALLOW_NO_STACK=1 to allow, or configure validate.sh)"
    fi
    ;;
esac

echo
if [ "$FAILED" -eq 0 ]; then
  printf '\033[1;32mGATE: GREEN\033[0m — ran:%s\n' "${RAN:- (nothing)}"
  exit 0
else
  printf '\033[1;31mGATE: RED\033[0m — one or more checks failed.\n'
  exit 1
fi
