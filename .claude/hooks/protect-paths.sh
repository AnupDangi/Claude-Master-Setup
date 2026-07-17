#!/usr/bin/env bash
# PreToolUse(Write|Edit) hook: warn (not block) before touching protected files.
# Exit 0 always — this is guidance, not a gate.
INPUT="$(cat)"
FP="$(printf '%s' "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')"
[ -z "$FP" ] && exit 0
base="$(basename "$FP")"
case "$base" in
  .env|.env.*)                echo "NOTE: editing an env file ($base). Never commit real secrets." >&2 ;;
  package-lock.json|pnpm-lock.yaml|yarn.lock|Cargo.lock|poetry.lock|uv.lock)
                              echo "NOTE: editing a lockfile ($base). Prefer changing manifests and regenerating." >&2 ;;
  *.yml|*.yaml)               case "$FP" in *.github/workflows/*|*.gitlab-ci*) echo "NOTE: editing CI config ($base). Double-check before merge." >&2 ;; esac ;;
esac
exit 0
