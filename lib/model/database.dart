// package imports
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
// local references
import 'package:tune_trove/model/accessors/recording_dao.dart';
import 'package:tune_trove/model/accessors/set_dao.dart';
import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/model/accessors/tune_dao.dart';
import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database.steps.dart';
import 'package:tune_trove/model/tables/recordings.dart';
import 'package:tune_trove/model/tables/set_tune.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/model/tables/tune_recording.dart';
import 'package:tune_trove/model/tables/tunes.dart';

// generated code
part 'database.g.dart';

@DriftDatabase(
  tables: [Recordings, Tunes, TuneRecording, TuneSets, SetTune],
  daos: [TuneDao, RecordingDao, TuneRecordingDao, SetDao, SetTuneDao],
)
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
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
    ),
  );

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
