# AGENTS.md

Repository instructions for future agent sessions.

## Structure

- `glot_backend` contains the backend application.
- `glot_core` contains shared domain types and helpers.
- `glot_frontend` contains the frontend application.

## Backend Conventions

- Prefer domain types from `glot_core` over duplicating equivalent backend-local types.
- `glot_backend/program/handlers.gleam` is the boundary where SQL rows should be converted into domain types.
- Keep generated SQL row types confined to the DB layer when possible.
- Imports should only import the type that matches the module name. Example: from `glot_backend/api_action`, only import `ApiAction`; do not import constructors like `RunAction` or `SendLoginTokenAction` directly.

## Generated Files

- `glot_backend/src/glot_backend/sql.gleam` is generated. Do not hand-edit it unless the task explicitly requires a temporary/manual fix.
- Prefer changing the SQL source files or generation inputs, then regenerating `sql.gleam`.

## Database

- `glot_backend/init.sql` is the schema source of truth in this repo.

## Validation

- After backend changes, run `gleam test` in `glot_backend`.
