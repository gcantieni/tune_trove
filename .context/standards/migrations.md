# Database Migrations

How to evolve the Drift schema (`lib/model/database.dart`) without breaking
existing installs. Read alongside [drift.md](/.context/standards/drift.md).

## The golden rule: hand-written migration steps must be idempotent

Drift runs `onUpgrade` and only writes the new `user_version` **after the whole
callback returns successfully**. But SQLite auto-commits each DDL statement the
moment it executes. So if a migration runs several statements and any one of
them throws — or the app is killed mid-migration — the earlier statements have
**already persisted to disk**, yet `user_version` is still the old value.

On the next launch drift sees the old version and **re-runs the same
`from < N` branch**, replaying DDL against objects that now already exist:

```
SqliteException(1): duplicate column name: position
  Causing statement: ALTER TABLE "tune_sets" ADD COLUMN "position" ...
```

This is not hypothetical — it shipped. The v11→v12 step used a bare
`m.addColumn(tuneSets, tuneSets.position)`; a later interrupted upgrade left the
column present at `user_version = 11`, and every subsequent launch crashed in the
same spot. Fix: guard the add with a column-existence check.

```dart
// SQLite has no `ADD COLUMN IF NOT EXISTS`, so check first.
if (from < 12 &&
    to >= 12 &&
    !await _columnExists('tune_sets', 'position')) {
  await m.addColumn(tuneSets, tuneSets.position);
  await customStatement('UPDATE tune_sets SET position = ...');
}

Future<bool> _columnExists(String table, String column) async {
  final cols = await customSelect('PRAGMA table_info("$table")').get();
  return cols.any((r) => r.read<String>('name') == column);
}
```

### What needs a guard, and what doesn't

| Operation                              | Idempotent on re-run? | Action |
| -------------------------------------- | --------------------- | ------ |
| `m.createTable(x)`                      | ✅ drift emits `CREATE TABLE IF NOT EXISTS` | nothing |
| `m.createIndex` / `createTrigger`       | ✅ `IF NOT EXISTS`     | nothing |
| `m.addColumn(...)`                      | ❌ raw `ALTER TABLE ADD COLUMN` | guard with `_columnExists` |
| raw `customStatement('ALTER TABLE …')` | ❌                     | guard by hand (PRAGMA / `sqlite_master`) |
| `m.alterTable(TableMigration(...))`     | recreates the table; safe if it completes | keep as a single step |
| data backfill (`UPDATE …`)              | depends on the query  | make it re-runnable (idempotent `UPDATE`) or fold it inside the same existence guard as the column it backfills |

Prefer `createTable`/`createIndex` for additive changes — they're free of this
hazard. Reach for a guarded `addColumn` only when adding a column to an existing
table.

## Workflow when changing the schema

1. Edit the table in `lib/model/tables/` and/or `@DriftDatabase` in
   `lib/model/database.dart`, then bump `schemaVersion`.
2. Add the upgrade branch in `onUpgrade`. The generated `stepByStep` covers
   v1→v9; everything after is a hand-written `if (from < N && to >= N)` block —
   keep those **idempotent** per the table above.
3. Regenerate code and capture a schema snapshot:
   ```
   make deps                                     # build_runner (database.g.dart, .steps.dart)
   dart run drift_dev schema dump \
     lib/model/database.dart drift_schemas/      # snapshot the new version
   dart run drift_dev schema generate \
     drift_schemas/ test/drift/my_database/generated/
   ```
4. **Always update the migration test suite**
   (`test/drift/my_database/migration_test.dart`) — this is a hard project rule.
   The auto-generated "simple database migrations" group only exercises *clean*
   schema-at-N → M upgrades, so it will **not** catch the interrupted-migration
   crash above. For any hand-written `addColumn`/raw-DDL step, also add an
   "idempotent re-run" test that:
   - builds the prior schema with the generated `DatabaseAtV<N>`,
   - applies the half-finished DDL by hand (leaving `user_version` at N),
   - opens the real `AppDatabase` and asserts the upgrade completes without
     throwing and lands at the latest `schemaVersion`.
5. Run `make format && make analyze && make test`.

## iOS / production notes

- The on-device DB lives under `getApplicationSupportDirectory` (see
  `_openConnection`). Deleting the app resets it; an in-place upgrade does not —
  which is exactly why a botched migration bricks launch on every start until
  fixed.
- CloudKit sync layers on top of this schema. Dedupe keys (`ts_id`/`name`) and
  the `cloud_id` columns are migration-sensitive — never drop or rename them
  without a data-preserving `alterTable` step plus a data-integrity test.

## Promoting a new column to the CloudKit Production schema

Adding a synced column doesn't need a separate CloudKit migration: the Drift
migration is idempotent and the column flows through the sync layer, which
applies it to the CloudKit schema automatically (CKSyncEngine creates the field
in the **Development** environment on first sync of a record carrying it). The
manual step is promotion:

> The migration is idempotent and applies the column to the CloudKit schema.
> When you have tested and are satisfied, make sure to promote the Development
> schema to Production on the iCloud.developer.apple.com portal.

Do this before shipping a build that writes the new field to users' Production
containers.
