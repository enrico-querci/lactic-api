# AGENTS.md — Lactic API

> Rails-specific agent instructions for `lactic-api`.
> This file complements the root AGENTS.md at the repository root, which contains
> the full domain context, data model, and shared conventions. Always read both.

---

## Platform

- **Ruby:** 3.3+
- **Rails:** 8.0+ (API-only)
- **Database:** PostgreSQL

## Architecture

- API-only — no views, no asset pipeline, no server-rendered HTML.
- All endpoints under `/api/v1/` with JSON responses.
- RESTful routes following Rails conventions.
- Leverage Rails 8 features where appropriate: built-in authentication generator, Solid Queue, Solid Cache.

## Code Style

- `snake_case` for everything: tables, columns, endpoints, variables, methods.
- Follow Rails conventions: strong parameters, concerns for shared logic, service objects for complex operations.
- Use concerns to share behavior between models (e.g. a `Positionable` concern for ordered records).

## Migrations

- Always include appropriate indexes (especially on foreign keys and columns used in queries).
- Always use constraints: `null: false` where applicable, `foreign_key: true` on references.
- Use `add_reference` with `foreign_key: true` rather than raw `add_column` for associations.

## Auth

- JWT with refresh tokens.
- Sign In with Apple + Google Sign-In (no email+password in v1).
- Two roles: `coach` and `client` — a user is one or the other.
- Scope API endpoints appropriately: coach endpoints require coach role, client endpoints require client role.

## Serialization

- TBD (jbuilder, blueprinter, or alba). Be consistent once chosen.
- Always return only the fields the client needs — avoid exposing full ActiveRecord objects.

## Testing

- TBD (Minitest or RSpec). Be consistent once chosen.
- Write model tests for validations and associations.
- Write request tests for API endpoints (happy path + error cases).

## Developer Context

The developer has limited Rails experience. When writing code or suggesting commands:
- Explain Rails-specific concepts briefly (e.g. what a migration does, what `has_many through:` means).
- Show the full command to run (e.g. `rails generate model ...` with all arguments).
- When there are multiple Rails ways to do something, pick the simplest and most conventional one.
