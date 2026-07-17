# Architectural Decisions (ADRs)

> Append-only. One entry per significant decision. The architect writes these; never
> silently reverse one — supersede it with a new ADR that references the old.

## ADR template
```
## ADR-NNN: <short title>
- Date: YYYY-MM-DD
- Status: proposed | accepted | superseded by ADR-XXX
- Context: what forced a decision (constraints, scale, requirements)
- Options considered: A / B / C — with the key trade-off of each
- Decision: what we chose
- Consequences: what this makes easy, what it makes hard, what we accept
```

---

## ADR-000: Adopt the self-contained loop harness
- Date: _(set on bootstrap)_
- Status: accepted
- Context: the project needs a repeatable, validated build process that any session
  can continue from the repository alone.
- Options considered: freeform chat (no structure) / external plugin harness
  (dependency + drift risk) / self-contained loop + agents in-repo.
- Decision: self-contained harness — agents, commands, hooks, and gates live in this
  repo, no external marketplace required.
- Consequences: fully portable and reviewable; the repo owns its own quality gates;
  in exchange we maintain the harness files ourselves.
