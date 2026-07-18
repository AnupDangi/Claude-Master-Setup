# Model Routing

## What's built today

Model choice is **mostly static**, pinned per agent in that agent's
frontmatter (`.claude/agents/*.md`) — with one dynamic exception for the
BUILD phase (below):

| Tier | Model | Agents | Rationale |
|---|---|---|---|
| Mechanical | Haiku | `docs-writer` | Formatting, status, small mechanical doc edits — cheap and sufficient |
| Engineering | Sonnet | `implementer` (default), `validator`, `reviewer`, `mcp-scout`, `evaluator` | Building, validating, reviewing, wiring tools, scoring — normal engineering judgment |
| Judgment | Opus | `orchestrator`, `planner`, `architect`, `security`, `implementer-opus` | Orchestration, planning, architecture, security review, and BUILD for `large`-complexity tasks — highest cost of a wrong call |

The rule of thumb (from `CLAUDE.md`): **use the cheapest model that can do the
task well**, and escalate only when complexity justifies the cost. This is a
convention enforced by whoever edits agent frontmatter for every agent except
`implementer`, which now has a real dynamic choice at BUILD time.

### Built: `implementer` / `implementer-opus`

The first (and, deliberately, only) dynamic-routing pair. At BUILD, the
orchestrator delegates to `implementer` (Sonnet, default) unless this task's
`loop.json.task_complexity` — set once per task at the start of PLAN, see
`docs/LOOP.md` — is `large`, in which case it delegates to `implementer-opus`
instead. Same job, same output contract, only the model tier differs. The
fix cycle after a RED validation stays with whichever variant built the task.

This directly follows the mechanism below: since the `Task` tool can't
override a subagent's model per call, `implementer-opus.md` is a real,
separate agent file, not a runtime flag. It's the "one high-value pair"
this doc previously said to start with — chosen because `implementer` is the
most-invoked agent (every BUILD) and escalating (not downgrading) is the
safer direction to bet on: a weaker model on trivial tasks risks quality loss
for little savings, a stronger model on `large` tasks buys real robustness on
the tasks most likely to have edge cases. No other agent has a variant yet —
extend this pattern to another agent only when a specific one shows the same
"most-invoked + complexity-sensitive" shape `implementer` did.

## Target design: scheduler-driven routing

The Loop Engine's target design (`LOOP_ENGINE.md`) adds a **Choose Model**
step after **Estimate Cost**, so model selection becomes dynamic per task
instead of static per agent:

```
Task → Estimate Cost → Choose Model → (route to Haiku / Sonnet / Opus)
```

Example strategy:

```
Simple tasks (docs, formatting, status)         → Haiku
Medium tasks (implementation, validation, review) → Sonnet
Complex tasks (architecture, security, planning)  → Opus
```

This is the same three tiers used today — the change is *where* the decision
is made, and how many agents it applies to. The `implementer`/`implementer-opus`
pair above is one instance of exactly this pattern, applied to one agent using
the coarse `task_complexity` label. The full target goes further: a real
token/time cost estimate (not just a 4-way label) feeding routing decisions
across every agent, not just BUILD — e.g. routing a trivial architectural
question to Sonnet instead of always paying for Opus on `architect`. **That
broader version is not built** — extending the variant-pair pattern to other
agents is roadmap work (`docs/ROADMAP.md`), done one agent at a time and only
once that agent shows the same "most-invoked + complexity-sensitive" shape
that justified doing `implementer` first.

### Platform constraint: how this actually has to work

Claude Code's `Task` tool has **no parameter to override a subagent's model
per invocation** — model is fixed by that subagent file's own `model:`
frontmatter (see the [sub-agents](https://code.claude.com/docs/en/sub-agents.md)
and [tools reference](https://code.claude.com/docs/en/tools-reference.md)
docs). So "dynamic routing" cannot mean the orchestrator passing a model
choice into an existing agent at call time. The only supported mechanism is:
define **named, per-tier variant files** for an agent (e.g. `implementer.md`
pinned to Sonnet, `implementer-opus.md` for hard ones — built) and have the
orchestrator pick *which file to delegate to* based on `task_complexity`. This
means "dynamic model routing" is really "orchestrator chooses among
pre-defined agent variants" — each variant is a real file to maintain, not a
runtime flag. Extending this to more agents means more files to keep in sync
with their default counterpart (as `implementer-opus.md` is with
`implementer.md` today) — factor that maintenance cost in before adding one
for every agent "just in case."
