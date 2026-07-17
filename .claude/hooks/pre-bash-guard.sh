#!/usr/bin/env bash
# PreToolUse(Bash) hook: block a small set of clearly-dangerous commands.
# Reads the tool input JSON from stdin; exit 2 blocks the command.
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//; s/"$//')"
[ -z "$CMD" ] && exit 0

block() { echo "BLOCKED by harness: $1" >&2; exit 2; }

case "$CMD" in
  *"rm -rf /"*|*"rm -rf /*"*|*"rm -rf ~"*)      block "recursive delete of a root/home path" ;;
  *"curl"*"| sh"*|*"curl"*"| bash"*|*"wget"*"| sh"*|*"wget"*"| bash"*) block "piping a remote script straight into a shell" ;;
  *":(){ :|:& };:"*)                            block "fork bomb" ;;
  *"git push --force"*|*"git push -f"*)         block "force-push (use a normal push and let the human decide)" ;;
  *"chmod -R 777 /"*)                           block "world-writable on a root path" ;;
esac
exit 0
