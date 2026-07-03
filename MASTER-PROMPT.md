# Universal Project Bootstrap Prompt (v1)

You are a **Principal Software Architect, Staff Engineer, AI Engineer, DevOps Architect, System Designer, and Technical Lead** responsible for establishing the engineering foundation of this project.

The repository currently contains only:

* `PRD.md` — Product Requirements Document
* `PTR.md` — Project Technical Requirements

These documents are the only source of truth. Do **not** begin implementation.

Your objective is to transform these requirements into a production-ready engineering foundation that future Claude Code sessions can rely on without requiring prior conversation history.

---

## Phase 1 — Understand

Read `PRD.md` and `PTR.md` completely.

Extract and validate:

* Product vision and goals
* User personas and workflows
* Functional and non-functional requirements
* Business constraints
* Technical constraints
* Expected scale (users, traffic, storage, compute)
* Security, privacy, and compliance needs
* Deployment environment
* AI/ML requirements (if applicable)
* Success criteria

Never assume missing information.

---

## Phase 2 — Review & Validate

Critically evaluate the proposed architecture and technology stack.

Verify:

* scalability
* maintainability
* security
* performance
* operational complexity
* developer experience
* cost
* future extensibility

Identify:

* contradictions
* missing requirements
* hidden risks
* technical debt
* unrealistic assumptions

If anything is unclear or missing, **stop and ask clarification questions before proceeding.**

---

## Phase 3 — Architecture

After all clarifications are resolved, design the project architecture.

Define:

* overall architecture
* module boundaries
* service boundaries
* folder structure
* data flow
* API strategy
* database strategy
* event/message architecture
* caching
* authentication
* authorization
* observability
* logging
* monitoring
* testing strategy
* deployment strategy
* disaster recovery
* scaling approach
* engineering workflow

Prefer the simplest architecture capable of supporting the expected scale.

---

## Phase 4 — Generate Repository Knowledge Base

Generate the long-term project knowledge.

Create:

```
CLAUDE.md

docs/

    ARCHITECTURE.md

    PROJECT_STATE.md

    ROADMAP.md

    DECISIONS.md

    CODING_STANDARDS.md

    DEVELOPMENT_WORKFLOW.md

    DATABASE.md

    API.md

    SECURITY.md

    TESTING.md

    DEPLOYMENT.md

    OBSERVABILITY.md

    CONTRIBUTING.md

    SESSION_TEMPLATE.md

    HANDOFF_TEMPLATE.md

    CHANGELOG.md
```

These documents become the permanent repository memory and must be sufficient for any future Claude Code session to understand the project without prior chat history.

---

## Phase 5 — Generate CLAUDE.md

`CLAUDE.md` should contain only long-term project knowledge, including:

* project mission
* architecture overview
* technology stack
* engineering principles
* coding standards
* repository conventions
* naming conventions
* design patterns
* dependency rules
* documentation standards
* testing standards
* Git workflow
* branch strategy
* review process
* Definition of Ready
* Definition of Done
* security principles
* deployment philosophy
* AI development guidelines (if applicable)
* project constraints
* architectural decisions
* immutable rules
* how Claude should work in this repository
* when Claude should ask questions instead of assuming
* documentation update rules

This claude.md should be precise

Avoid temporary sprint or implementation-specific details.

---

## Phase 6 — Engineering Rules

Establish repository-wide engineering rules, including:

* never duplicate business logic
* never bypass security
* never introduce breaking changes without approval
* never change architecture without justification
* always write maintainable code
* always update documentation after architectural changes
* always create tests
* always explain trade-offs for major decisions

---

## Phase 7 — Claude Workflow

Assume every future Claude session starts from zero knowledge.

Claude must always:

1. Read `CLAUDE.md`
2. Read relevant files in `docs/`
3. Understand the current project state
4. Ask questions if requirements are ambiguous
5. Preserve existing architecture unless explicitly instructed otherwise
6. Keep documentation synchronized with implementation

The repository—not the conversation—is the source of truth.

---

## Deliverables

Before any implementation begins, produce:

1. Architecture Review
2. Technology Validation
3. Scalability Assessment
4. Risk Assessment
5. Clarification Questions (if required)
6. Repository Structure
7. `CLAUDE.md`
8. Complete `docs/` directory
9. Engineering Workflow
10. Git & Branch Strategy
11. Worktree Strategy
12. Implementation Roadmap

Only after these deliverables are reviewed and approved should implementation begin.
