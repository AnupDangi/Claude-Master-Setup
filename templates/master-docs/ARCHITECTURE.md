# Architecture

> Generated/refined by `/bootstrap`. Keep this consistent with `CLAUDE.md` and the
> ADRs in `DECISIONS.md`. The loop's planner and architect read this to stay within
> the approved design.

## System overview
_(one-paragraph description + a diagram of the major components and how requests flow)_

## Components & responsibilities
| Component | Responsibility | Talks to |
|---|---|---|
| _(service/module)_ | _(what it owns)_ | _(dependencies)_ |

## Data flow
_(trace a primary user action end-to-end)_

## Boundaries & interfaces
_(service/module boundaries; public interfaces; what must never cross a boundary)_

## Expected scale (the numbers the design must hold)
- Users / concurrency: _(fill in from PTR)_
- Request rate: _(…)_
- Data volume / growth: _(…)_
- Latency / SLA targets: _(…)_

## Scaling strategy
_(how each tier scales; where the first bottleneck will appear and the plan for it)_

## Cross-cutting concerns
Auth · caching · logging · error handling · config — one line each, pointing to the
detailed doc where relevant.

## Non-goals
_(explicitly out of scope, so the loop doesn't drift into building them)_
