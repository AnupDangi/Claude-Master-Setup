# Database

> Schema, migrations, and access rules. Update in the same iteration as any schema
> change (the loop's DoD requires it). Fill in on bootstrap if the project has a DB.

## Engine & why
_(Postgres/MySQL/SQLite/…, and the reason — tie back to ARCHITECTURE scale numbers)_

## Schema
_(tables/collections, key columns, relationships. A diagram helps. Keep in sync with
migrations — this doc describes the current schema.)_

## Migrations
- Tool: _(e.g. Prisma / Alembic / sqlx / Flyway)_
- Rule: every schema change is a migration, reviewed, reversible where possible.
- Never edit a shipped migration; add a new one.

## Access
- Connection via env var (`DATABASE_URL`), never hardcoded.
- The MCP DB server (if added) uses a **read-only** user unless writes are required
  — see `docs/MCP.md`.

## Indexing & performance
_(indexes that exist and why; known hot queries; expected growth)_

## Backup & recovery
_(policy, if applicable)_
