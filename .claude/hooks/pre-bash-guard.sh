#!/usr/bin/env bash
# PreToolUse(Bash): block a small set of clearly-dangerous commands.
# Exit 2 blocks. Parses tool JSON with python3 (embedded quotes safe).
set -euo pipefail

INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | python3 -c '
import json, re, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    m = re.search(r"\"command\"\s*:\s*\"((?:\\.|[^\"\\])*)\"", raw)
    print((bytes(m.group(1), "utf-8").decode("unicode_escape") if m else ""))
    raise SystemExit(0)
cmd = data.get("command") or ""
ti = data.get("tool_input")
if not cmd and isinstance(ti, dict):
    cmd = ti.get("command") or ""
print(cmd or "")
')"

[ -z "$CMD" ] && exit 0

block() { echo "BLOCKED by harness: $1" >&2; exit 2; }

case "$CMD" in
  *"rm -rf /"*|*"rm -rf /*"*|*"rm -rf ~"*|*"rm -rf ~/"*) block "recursive delete of a root/home path" ;;
esac

if printf '%s' "$CMD" | grep -Eqi 'curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh'; then
  block "piping a remote script straight into a shell"
fi

case "$CMD" in
  *":(){ :|:& };:"*) block "fork bomb" ;;
  *"git push --force"*|*"git push -f"*) block "force-push (use a normal push and let the human decide)" ;;
  *"chmod -R 777 /"*) block "world-writable on a root path" ;;
esac
exit 0
