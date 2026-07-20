#!/usr/bin/env bash
# PreToolUse(Write|Edit|MultiEdit): BLOCK secrets/lockfiles/CI/control-plane
# unless HARNESS_ALLOW_PROTECTED_EDITS=1. Exit 2 blocks. JSON via python3.
set -euo pipefail

allow="${HARNESS_ALLOW_PROTECTED_EDITS:-0}"
INPUT="$(cat)"

FP="$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    m = re.search(r"\"file_path\"\s*:\s*\"((?:\\.|[^\"\\])*)\"", raw)
    print((bytes(m.group(1), "utf-8").decode("unicode_escape") if m else ""))
    raise SystemExit(0)
fp = data.get("file_path") or data.get("path") or ""
ti = data.get("tool_input")
if not fp and isinstance(ti, dict):
    fp = ti.get("file_path") or ti.get("path") or ""
print(fp or "")
')"

[ -z "$FP" ] && exit 0

block() {
  echo "BLOCKED by harness protect-paths: $1" >&2
  echo "Set HARNESS_ALLOW_PROTECTED_EDITS=1 only if you intentionally must edit this file." >&2
  exit 2
}
warn() { echo "NOTE: $1" >&2; }

base="$(basename "$FP")"
norm="$(printf '%s' "$FP" | tr '\\' '/')"

case "$base" in
  id_rsa|id_ed25519|*.pem|*.PEM) block "editing credential material ($base)" ;;
esac

case "$base" in
  .env.example) ;;
  .env|.env.*|*.env)
    if [ "$allow" = "1" ]; then warn "editing env file $base (override on)"; exit 0; fi
    block "editing env/secrets file ($base)"
    ;;
esac

case "$base" in
  package-lock.json|pnpm-lock.yaml|yarn.lock|Cargo.lock|poetry.lock|uv.lock|Gemfile.lock|composer.lock)
    if [ "$allow" = "1" ]; then warn "editing lockfile $base (override on)"; exit 0; fi
    block "editing lockfile ($base)"
    ;;
esac

case "$norm" in
  *.github/workflows/*|*/.github/workflows/*|*.gitlab-ci.yml|*/.gitlab-ci.yml|*/.circleci/*)
    if [ "$allow" = "1" ]; then warn "editing CI config $FP (override on)"; exit 0; fi
    block "editing CI config ($FP)"
    ;;
esac

control_plane=0
case "$norm" in
  */.claude/hooks/*|.claude/hooks/*|*/.claude/settings.json|.claude/settings.json) control_plane=1 ;;
  */.claude/agents/*|.claude/agents/*|*/.claude/commands/*|.claude/commands/*) control_plane=1 ;;
  */scripts/validate.sh|scripts/validate.sh) control_plane=1 ;;
  # ADR-007 shared framework (npm): hooks/scripts under claude-master-setup/
  */claude-master-setup/hooks/*|*/claude-master-setup/scripts/*) control_plane=1 ;;
esac
case "$base" in
  validate.sh|setup-loop.sh|cancel-loop.sh|worktree-fanout.sh|pre-bash-guard.sh|protect-paths.sh|require-agents-before-edit.sh|self-check.sh|session-start.sh|post-edit-track.sh|loop-stop-hook.sh|stop-validate-reminder.sh)
    control_plane=1 ;;
esac

# Block writes under the active shared framework root (npm path)
framework_root="${CLAUDE_MASTER_ROOT:-${HARNESS_FRAMEWORK_ROOT:-}}"
if [ -n "$framework_root" ]; then
  fw="$(printf '%s' "$framework_root" | tr '\\' '/' | sed 's:/*$::')"
  case "$norm" in
    "$fw"|"$fw"/*) control_plane=1 ;;
  esac
fi

if [ "$control_plane" = "1" ]; then
  if [ "$allow" = "1" ]; then warn "editing harness control-plane file $FP (override on)"; exit 0; fi
  block "editing harness control-plane ($FP)"
fi
exit 0
