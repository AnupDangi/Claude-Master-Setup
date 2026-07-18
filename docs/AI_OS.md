# AI OS layer

> Systems that turn the harness from a gated loop into a controllable
> autonomous engineering OS. Companion to [`LOOP.md`](LOOP.md),
> [`EVALUATION.md`](EVALUATION.md), [`SECURITY.md`](SECURITY.md).

## Built (this milestone)

| Capability | Mechanism |
|---|---|
| Persistent loop event log | `scripts/loop-event.sh` → `.claude/state/history/events.jsonl` |
| Eval → SELECT feedback | `scripts/write-scorecard.sh` → `.claude/state/last_scorecard.json`; orchestrator reads on SELECT |
| Harness CI | `.github/workflows/harness-ci.yml` |
| Hard path blocking | `.claude/hooks/protect-paths.sh` exit 2 (override: `HARNESS_ALLOW_PROTECTED_EDITS=1`) |
| Cost/budget stop | `scripts/budget-check.sh` + env caps + orchestrator STOP |
| Multi-session coordinator | `scripts/lease.sh` roadmap item leases |
| Brownfield `/bootstrap` | Detect existing codebase; infer stack/conventions; still no feature code |
| Build-effort value function | `scripts/estimate-build-effort.sh` → `fast\|standard\|rigorous` (thin docs vs full harness); REVIEW+SECURITY always |
| Build-effort dial | `scripts/estimate-build-effort.sh` → `fast\|standard\|rigorous` ([`BUILD_EFFORT.md`](BUILD_EFFORT.md)) |

## Event log

```bash
bash scripts/loop-event.sh select '{"task":"..."}'
bash scripts/loop-event.sh validate_red '{"attempt":1}'
bash scripts/loop-event.sh await_human_on_red '{}'
bash scripts/loop-event.sh commit '{"message":"feat: ..."}'
bash scripts/loop-event.sh summary   # JSON: total, by_type, manual_interventions, loop_commits
```

Orchestrator **must** emit events at phase transitions. Evaluator uses
`summary.manual_interventions` and `loop_commits` instead of "not tracked".

## Scorecard → SELECT

After `/evaluate`, persist:

```bash
bash scripts/write-scorecard.sh '{"tests":"RED","iterations":12,"docs_filled":3,"docs_total":9,"manual_interventions":2}'
```

On SELECT, if `last_scorecard.json` exists:

- Tests RED → prefer fix/validate-related roadmap work or stop and report
- Docs completeness low → prefer docs/roadmap hygiene items when unblocked
- High manual_interventions → prefer smaller next tasks / escalate to human

Never invent roadmap items solely from the scorecard — only bias among
unblocked items already on `docs/ROADMAP.md`.

## Budget stop

```bash
bash scripts/budget-check.sh   # exit 3 = STOP
```

| Env | Default |
|---|---|
| `HARNESS_MAX_ITERATIONS_PER_RUN` | 1 |
| `HARNESS_MAX_COMMITS_PER_DAY` | 20 |
| `HARNESS_MAX_EVENTS_PER_DAY` | 200 |
| `HARNESS_BUDGET_STOP` | 1 |

## Leases (multi-session)

```bash
bash scripts/lease.sh acquire "Scoring" my-worktree
bash scripts/lease.sh heartbeat "Scoring" my-worktree
bash scripts/lease.sh release "Scoring" my-worktree
```

TTL: `HARNESS_LEASE_TTL_SECONDS` (default 7200). Stale leases auto-expire.
Orchestrator acquires before BUILD; releases after COMMIT or on abandon.

## Build effort (complexity → speed dial)

```bash
bash scripts/estimate-build-effort.sh --write
# override: HARNESS_BUILD_EFFORT_TIER=fast|standard|rigorous
```

Generic / known patterns → **fast** (thin docs, outcome-first). Novel / multi-phase /
high-risk → **rigorous**. **VALIDATE + REVIEW + SECURITY always run.** Full spec:
[`BUILD_EFFORT.md`](BUILD_EFFORT.md).

## Brownfield bootstrap

When `PRD.md`/`PTR.md` are missing but a codebase exists (`package.json`,
`Cargo.toml`, `go.mod`, `pyproject.toml`, etc.):

1. Run `bash scripts/detect-stack.sh`
2. Infer conventions from existing tree (read, don't invent)
3. Generate or draft `PRD.md`/`PTR.md` from observed reality + human confirmation
4. Architect ADRs for *current* architecture (document, don't rewrite)
5. Coarse `docs/ROADMAP.md` for adoption (tests/docs/gates first)
6. Still **no feature code** in bootstrap

See `/bootstrap` command and [`SETUP.md`](SETUP.md).
