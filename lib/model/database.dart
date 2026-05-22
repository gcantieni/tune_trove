// package imports
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
  int get schemaVersion => 6;

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
