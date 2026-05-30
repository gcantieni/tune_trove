// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/database.dart';
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v6.dart' as v6;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The "simple" suite above only ever runs a migration against a *clean*
  // schema-at-N database, so it cannot catch the most common production failure
  // mode for our hand-written (post-v9) migration steps: a partial/interrupted
  // migration. SQLite applies each DDL statement immediately, but drift only
  // bumps `user_version` after the *whole* onUpgrade callback succeeds. If any
  // later step throws (or the app is killed) after an earlier `ADD COLUMN` /
  // `CREATE TABLE` already ran, the next launch re-enters the same `from < N`
  // branch and re-runs that DDL against an object that now already exists —
  // crashing with "duplicate column name" / "table already exists".
  //
  // These tests reproduce that state by hand (apply the DDL, leave
  // `user_version` where it was) and assert the real AppDatabase migration is
  // safe to re-run. See .context/standards/migrations.md.
  group('idempotent re-run of interrupted migrations', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('tune_trove_mig');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    Future<int> userVersion(GeneratedDatabase db) async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      return row.read<int>('user_version');
    }

    test(
      'v11->v13 survives a half-applied v11->v12 (tune_sets.position already '
      'added)',
      () async {
        final file = File('${tmpDir.path}/position.sqlite');

        // Build the real v11 schema, then simulate an interrupted v11->v12:
        // the column was added but drift never committed v12, so user_version
        // is still 11.
        final old = v11.DatabaseAtV11(
          NativeDatabase(file),
        );
        await old.customStatement('SELECT 1'); // open + createAll @ v11
        await old.customStatement(
          'ALTER TABLE "tune_sets" '
          'ADD COLUMN "position" INTEGER NOT NULL DEFAULT 0',
        );
        expect(await userVersion(old), 11);
        await old.close();

        // Opening the real database triggers onUpgrade(11 -> 13). Before the
        // idempotency guard this throws: duplicate column name: position.
        final app = AppDatabase(NativeDatabase(file));
        await app.customStatement('SELECT 1');

        // Migration completed: version advanced and the column is queryable.
        expect(await userVersion(app), app.schemaVersion);
        await app.customSelect('SELECT position FROM tune_sets').get();
        await app.close();
      },
    );

    // Regression guard for the createTable-based steps (v9->v10, v10->v11,
    // v12->v13). These are already safe to re-run because drift emits
    // CREATE TABLE IF NOT EXISTS — this test locks that in so a future switch
    // to a raw `customStatement('CREATE TABLE ...')` can't silently reintroduce
    // the interrupted-migration crash.
    test(
      'v12->v13 survives a half-applied v12->v13 (app_settings already created)',
      () async {
        final file = File('${tmpDir.path}/app_settings.sqlite');

        // Build the real v12 schema, then simulate an interrupted v12->v13:
        // the table exists but user_version is still 12.
        final old = v12.DatabaseAtV12(NativeDatabase(file));
        await old.customStatement('SELECT 1'); // open + createAll @ v12
        await old.customStatement(
          'CREATE TABLE app_settings ("key" TEXT NOT NULL PRIMARY KEY)',
        );
        expect(await userVersion(old), 12);
        await old.close();

        // onUpgrade(12 -> 13) must not throw "table app_settings already
        // exists".
        final app = AppDatabase(NativeDatabase(file));
        await app.customStatement('SELECT 1');

        expect(await userVersion(app), app.schemaVersion);
        await app.close();
      },
    );
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldRecordingsData = <v1.RecordingsData>[];
    final expectedNewRecordingsData = <v2.RecordingsData>[];

    final oldTunesData = <v1.TunesData>[];
    final expectedNewTunesData = <v2.TunesData>[];

    final oldTuneRecordingData = <v1.TuneRecordingData>[];
    final expectedNewTuneRecordingData = <v2.TuneRecordingData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.recordings, oldRecordingsData);
        batch.insertAll(oldDb.tunes, oldTunesData);
        batch.insertAll(oldDb.tuneRecording, oldTuneRecordingData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewRecordingsData,
          await newDb.select(newDb.recordings).get(),
        );
        expect(expectedNewTunesData, await newDb.select(newDb.tunes).get());
        expect(
          expectedNewTuneRecordingData,
          await newDb.select(newDb.tuneRecording).get(),
        );
      },
    );
  });
}
