#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: record that source changed so the loop/Stop
# reminder knows validation is pending. Never fails.
ROOT="${CLAUDE_PROJECT_DIR:-.}"
INPUT="$(cat)"
FP="$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')"
case "$FP" in
  *.md|*.txt|*.json|*.lock) exit 0 ;;   # docs/config edits don't need the code gate
  "") exit 0 ;;
esac
mkdir -p "$ROOT/.master/state" 2>/dev/null
touch "$ROOT/.master/state/validation-pending" 2>/dev/null
exit 0
