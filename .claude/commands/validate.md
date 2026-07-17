---
description: Run the validation gate (format, lint, typecheck, tests, build)
allowed-tools: Task, Bash(bash scripts/:*), Bash(./scripts/:*)
model: sonnet
---

# Validation Gate

Delegate to the **validator** subagent to run `scripts/validate.sh` and report `GATE: GREEN` or `GATE: RED`.

On RED, produce the precise failure report (stage, file, line, cause) so the implementer can fix it. Do not fix code here — this command only runs and reports the gate.
