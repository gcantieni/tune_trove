# Drift Standards

## Table Definitions

- Define tables in `lib/model/tables/` — one file per table.
- Use `IntColumn get id => integer().autoIncrement()()` for single-column PKs.
- Use `Set<Column> get primaryKey => {...}` for composite PKs (see `TuneRecording`).
- Mark optional fields as `.nullable()`.
- Use `textEnum<E>()` for enum columns — the DB stores the enum name as text.
- Store URLs/URIs as text, never absolute filesystem paths.

## DAOs

- One DAO per table (or per logical aggregate) in `lib/model/accessors/`.
- Annotate with `@DriftAccessor(tables: [...])`.
- Expose `watch*` methods returning `Stream<T>` for reactive UI bindings.
- Expose `insert*`, `update*`, `delete*` for mutations.
- Keep queries in the DAO — pages and providers should not write raw SQL.

## Migrations

See [migrations.md](/.context/standards/migrations.md) for the full workflow and
the **idempotency rule** for hand-written steps (interrupted migrations crash on
re-run otherwise).

- Increment `schemaVersion` in `database.dart` for every schema change.
- Steps up to v9 use `stepByStep()` (schema-typed); later changes are
  hand-written `if (from < N && to >= N)` blocks that must be idempotent.
- Always test migrations with the generated schema versions in
  `lib/model/migration_schemas/`.
- After adding a migration, export and regenerate the schemas:
  ```bash
  dart run drift_dev schema dump lib/model/database.dart drift_schemas/
  dart run drift_dev schema generate drift_schemas/ lib/model/migration_schemas/
  ```

## Code Generation

- Run `dart run build_runner build --delete-conflicting-outputs` after any table/DAO change.
- Never edit `.g.dart` files manually.
- The `build.yaml` maps the database target for drift_dev schema tooling.

## Testing

- Always use `NativeDatabase.memory()` in tests for speed and isolation.
- Set `closeStreamsSynchronously: true` on the connection to avoid dangling async in tearDown.
- Test DAO operations directly — insert then query and assert.
- Test migrations by opening each schema version in sequence and verifying data survives.
