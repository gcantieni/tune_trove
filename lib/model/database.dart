// package imports
import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
// local references
import 'package:tune_trove/model/accessors/app_settings_dao.dart';
import 'package:tune_trove/model/accessors/recording_dao.dart';
import 'package:tune_trove/model/accessors/set_dao.dart';
import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/model/accessors/source_confirmation_dao.dart';
import 'package:tune_trove/model/accessors/source_rankings_dao.dart';
import 'package:tune_trove/model/accessors/tune_dao.dart';
import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database.steps.dart';
import 'package:tune_trove/model/tables/app_settings.dart';
import 'package:tune_trove/model/tables/recordings.dart';
import 'package:tune_trove/model/tables/set_tune.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/model/tables/source_confirmations.dart';
import 'package:tune_trove/model/tables/source_rankings.dart';
import 'package:tune_trove/model/tables/tune_recording.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';

// generated code
part 'database.g.dart';

@DriftDatabase(
  tables: [
    Recordings,
    Tunes,
    TuneRecording,
    TuneSets,
    SetTune,
    SourceConfirmations,
    SourceRankings,
    AppSettings,
  ],
  daos: [
    TuneDao,
    RecordingDao,
    TuneRecordingDao,
    SetDao,
    SetTuneDao,
    SourceConfirmationDao,
    SourceRankingsDao,
    AppSettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Invoked after a row in a synced table is created/updated/deleted, unless
  /// row events are suppressed. The sync layer registers this to stage the
  /// change for upload; the model layer itself stays sync-agnostic (no
  /// dependency on the cloudkit_sync feature).
  void Function(String recordType, String cloudId, {required bool deleted})?
  onRowChanged;

  /// Runs [body] without emitting row-change events. Used while applying remote
  /// changes so pulled rows aren't immediately re-staged for push.
  ///
  /// Suppression is scoped with a [Zone] rather than a flag so that a user edit
  /// that happens to interleave (at an `await`) with reconciliation's writes is
  /// still reported — only writes within [body]'s async chain are suppressed.
  Future<T> withSuppressedRowEvents<T>(Future<T> Function() body) {
    return runZoned(body, zoneValues: {#suppressSyncRowEvents: true});
  }

  /// Reports a mutation to a synced row. No-op while suppressed, when no
  /// listener is registered, or when the row has no cloud_id.
  void notifyRowChanged(
    String recordType,
    String? cloudId, {
    required bool deleted,
  }) {
    if (cloudId == null) return;
    if (Zone.current[#suppressSyncRowEvents] == true) return;
    onRowChanged?.call(recordType, cloudId, deleted: deleted);
  }

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // The generated step-by-step migrations cover v1..v9.
      final steps = stepByStep(
        from1To2: (m, schema) async {
          // The recordings table was reshaped: added name/url, dropped
          // file_path/location, performers became nullable. There is no
          // production data yet, so drop and recreate rather than reconcile
          // missing values for the new NOT NULL columns.
          await m.deleteTable('recordings');
          await m.createTable(schema.recordings);
        },
        from2To3: (m, schema) async {
          // tune_recording reshape: start_time/end_time/performers became
          // nullable, key_signature dropped, and a composite primary key
          // (tune_id, recording_id) was added so each link is uniquely
          // addressable and the DB rejects duplicates. Dedup any existing
          // rows first so the new PK constraint can take effect.
          await customStatement('''
          DELETE FROM tune_recording WHERE rowid NOT IN (
            SELECT MIN(rowid) FROM tune_recording GROUP BY tune_id, recording_id
          )
        ''');
          await m.alterTable(
            TableMigration(schema.tuneRecording),
          ); // ignore: experimental_member_use
        },
        from3To4: (m, schema) async {
          // Add cached SVG column for ABC rendering. Existing rows get
          // null; the abc_render module fills them in lazily on next save.
          await m.addColumn(schema.tunes, schema.tunes.abcSvg);
        },
        from4To5: (m, schema) async {
          await m.createTable(schema.tuneSets);
          await m.createTable(schema.setTune);
        },
        from5To6: (m, schema) async {
          await m.addColumn(
            schema.tuneRecording,
            schema.tuneRecording.performedKey,
          );
        },
        from6To7: (m, schema) async {
          // Change start_time/end_time from INTEGER to REAL for sub-second
          // precision. TableMigration recreates the table; existing integer
          // values are preserved as-is and read as doubles by the new RealColumn.
          await m.alterTable(TableMigration(schema.tuneRecording));
        },
        from7To8: (m, schema) async {
          await m.addColumn(schema.setTune, schema.setTune.key);
        },
        from8To9: (m, schema) async {
          // SQLite does not support ALTER TABLE ADD COLUMN IF NOT EXISTS, so we
          // check PRAGMA table_info first. This makes the step safe to re-run if
          // a previous attempt was interrupted before the schema version was
          // committed (e.g. app killed mid-migration).
          for (final table in [
            'tunes',
            'recordings',
            'tune_recording',
            'tune_sets',
            'set_tune',
          ]) {
            final cols = await customSelect(
              'PRAGMA table_info("$table")',
            ).get();
            final hasCloudId = cols.any(
              (r) => r.read<String>('name') == 'cloud_id',
            );
            if (!hasCloudId) {
              await customStatement(
                'ALTER TABLE "$table" ADD COLUMN cloud_id TEXT NULL',
              );
            }
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS '
              '"idx_${table}_cloud_id" ON "$table" (cloud_id)',
            );
          }

          // Assign stable UUIDs to any rows that don't have one yet.
          // Alias rowid to avoid any column-naming ambiguity with Drift's
          // customSelect row map, and use readNullable to defend against the
          // unlikely-but-observed null cast (Drift 2.27 read<T> does
          // `readNullableWithType(...) as T`, which throws for null + non-nullable T).
          for (final table in [
            'tunes',
            'recordings',
            'tune_recording',
            'tune_sets',
            'set_tune',
          ]) {
            final rows = await customSelect(
              'SELECT rowid AS rid FROM "$table" WHERE cloud_id IS NULL',
            ).get();
            for (final row in rows) {
              final rowid = row.readNullable<int>('rid');
              if (rowid == null) continue;
              await customStatement(
                'UPDATE "$table" SET cloud_id = \'${_uuidV4()}\' WHERE rowid = $rowid',
              );
            }
          }
        },
      );
      final stepsTarget = to < 9 ? to : 9;
      if (from < stepsTarget) await steps(m, from, stepsTarget);
      // v9 -> v10: add the synced source_confirmations table (purely additive).
      if (from < 10 && to >= 10) await m.createTable(sourceConfirmations);
      // v10 -> v11: add the source_rankings table (purely additive).
      if (from < 11 && to >= 11) await m.createTable(sourceRankings);
      // v11 -> v12: add a position column to tune_sets so sets are user-orderable.
      // Defaults to 0; backfill stable positions by id so existing sets keep a
      // deterministic order instead of all tying at 0.
      //
      // Guarded with PRAGMA table_info because SQLite has no ADD COLUMN IF NOT
      // EXISTS. Each DDL statement auto-commits immediately, but drift only
      // bumps the schema version after the whole onUpgrade callback succeeds. If
      // a later step (or an app kill) interrupts the migration after this ran,
      // the next launch re-enters this branch and, without the guard, crashes
      // with "duplicate column name: position". (createTable steps don't need
      // this — drift emits CREATE TABLE IF NOT EXISTS.) See
      // .context/standards/migrations.md.
      if (from < 12 &&
          to >= 12 &&
          !await _columnExists('tune_sets', 'position')) {
        await m.addColumn(tuneSets, tuneSets.position);
        await customStatement(
          'UPDATE tune_sets SET position = '
          '(SELECT COUNT(*) FROM tune_sets t2 WHERE t2.id < tune_sets.id)',
        );
      }
      // v12 -> v13: add the synced app_settings key-value table (purely additive).
      if (from < 13 && to >= 13) await m.createTable(appSettings);
      // v13 -> v14: add a nullable composer column to tunes ("who wrote it",
      // distinct from `from` = "who I learned it from"). Guarded with
      // _columnExists because SQLite has no ADD COLUMN IF NOT EXISTS and a
      // mid-migration kill would otherwise re-run this and crash with
      // "duplicate column name: composer". See .context/standards/migrations.md.
      if (from < 14 && to >= 14 && !await _columnExists('tunes', 'composer')) {
        await m.addColumn(tunes, tunes.composer);
      }
      // v14 -> v15: add a nullable `source` column to tunes recording where the
      // ABC notation came from (a content source *id*), distinct from the
      // user-editable `from`. Provenance had been overloaded onto `from`, which
      // users overwrite ("learned it from X" ≠ "whose notation this is"), so we
      // split it out. Column add is guarded (_columnExists) for interrupted-
      // migration safety. The backfill runs unconditionally within the branch
      // but is idempotent (only fills rows still missing a source), so a crash
      // after a partial backfill is recovered on the next launch. Existing
      // imports stored the source *name* in `from`; map name -> id via the
      // registry, the single source of truth for ids. See
      // .context/standards/migrations.md.
      if (from < 15 && to >= 15) {
        if (!await _columnExists('tunes', 'source')) {
          await m.addColumn(tunes, tunes.source);
        }
        for (final meta in allContentSources) {
          await customStatement(
            'UPDATE tunes SET source = ? WHERE source IS NULL AND "from" = ?',
            [meta.id, meta.name],
          );
        }
      }
      // v15 -> v16: re-render notation cached before key-signature injection.
      // Sources like thesession.org store the tune body with the key in a
      // separate field, so pre-v16 imports cached an SVG (and played MIDI) in
      // C major regardless of the real key. We can't run the WebView renderer
      // from a migration, so instead clear the stale cached SVG for any tune
      // whose ABC has no `K:` header line; the detail view re-renders it lazily
      // (via assembleAbc, folding in the tune's key) the next time it's opened.
      // Schema-only change is none — this is a pure, idempotent data backfill
      // (re-running re-nulls already-null rows, a no-op). Match a K: field at
      // the start of the ABC or after any newline, mirroring the multiline
      // `^K:` check in assembleAbc. See .context/standards/migrations.md.
      if (from < 16 && to >= 16) {
        await customStatement(
          'UPDATE tunes SET abc_svg = NULL '
          'WHERE abc_svg IS NOT NULL AND abc IS NOT NULL '
          "AND abc NOT LIKE 'K:%' "
          "AND abc NOT LIKE '%' || char(10) || 'K:%'",
        );
      }
    },
  );

  /// Whether [column] already exists on [table]. Lets hand-written `ADD COLUMN`
  /// migration steps (see [migration]) be safe to re-run after an interrupted
  /// migration — SQLite has no `ADD COLUMN IF NOT EXISTS`.
  Future<bool> _columnExists(String table, String column) async {
    final cols = await customSelect('PRAGMA table_info("$table")').get();
    return cols.any((r) => r.read<String>('name') == column);
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}

String _uuidV4() {
  final rng = Random.secure();
  final b = List<int>.generate(16, (_) => rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(List<int> s) =>
      s.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(b.sublist(0, 4))}-${hex(b.sublist(4, 6))}-'
      '${hex(b.sublist(6, 8))}-${hex(b.sublist(8, 10))}-${hex(b.sublist(10))}';
}
