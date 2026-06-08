// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/migration_schemas/schema.dart';
import 'package:tune_trove/model/migration_schemas/schema_v1.dart' as v1;
import 'package:tune_trove/model/migration_schemas/schema_v11.dart' as v11;
import 'package:tune_trove/model/migration_schemas/schema_v12.dart' as v12;
import 'package:tune_trove/model/migration_schemas/schema_v13.dart' as v13;
import 'package:tune_trove/model/migration_schemas/schema_v14.dart' as v14;
import 'package:tune_trove/model/migration_schemas/schema_v15.dart' as v15;
import 'package:tune_trove/model/migration_schemas/schema_v2.dart' as v2;
import 'package:tune_trove/model/migration_schemas/schema_v6.dart' as v6;

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
        final old = v11.DatabaseAtV11(NativeDatabase(file));
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

    test(
      'v13->v14 survives a half-applied v13->v14 (tunes.composer already added)',
      () async {
        final file = File('${tmpDir.path}/composer.sqlite');

        // Build the real v13 schema, then simulate an interrupted v13->v14:
        // the column was added but drift never committed v14, so user_version
        // is still 13.
        final old = v13.DatabaseAtV13(NativeDatabase(file));
        await old.customStatement('SELECT 1'); // open + createAll @ v13
        await old.customStatement(
          'ALTER TABLE "tunes" ADD COLUMN "composer" TEXT NULL',
        );
        expect(await userVersion(old), 13);
        await old.close();

        // Opening the real database triggers onUpgrade(13 -> 14). Without the
        // _columnExists guard this throws: duplicate column name: composer.
        final app = AppDatabase(NativeDatabase(file));
        await app.customStatement('SELECT 1');

        expect(await userVersion(app), app.schemaVersion);
        await app.customSelect('SELECT composer FROM tunes').get();
        await app.close();
      },
    );

    test(
      'v14->v15 survives a half-applied v14->v15 (tunes.source already added)',
      () async {
        final file = File('${tmpDir.path}/source.sqlite');

        // Build the real v14 schema, then simulate an interrupted v14->v15:
        // the column was added but drift never committed v15, so user_version
        // is still 14.
        final old = v14.DatabaseAtV14(NativeDatabase(file));
        await old.customStatement('SELECT 1'); // open + createAll @ v14
        await old.customStatement(
          'ALTER TABLE "tunes" ADD COLUMN "source" TEXT NULL',
        );
        expect(await userVersion(old), 14);
        await old.close();

        // Opening the real database triggers onUpgrade(14 -> 15). Without the
        // _columnExists guard this throws: duplicate column name: source.
        final app = AppDatabase(NativeDatabase(file));
        await app.customStatement('SELECT 1');

        expect(await userVersion(app), app.schemaVersion);
        await app.customSelect('SELECT source FROM tunes').get();
        await app.close();
      },
    );
  });

  // Data-integrity test for the v14->v15 backfill: pre-v15, a tune's ABC
  // provenance lived in the editable `from` column. The migration copies it
  // into the new immutable `source` column — mapping the stored source *name*
  // to its registry *id* — but only when `from` matches a known content
  // source, so user-typed free text and null are left as a null source.
  group('v14->v15 backfills source from from', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('tune_trove_backfill');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    test('maps known source names to ids and leaves free text null', () async {
      final file = File('${tmpDir.path}/backfill.sqlite');

      final old = v14.DatabaseAtV14(NativeDatabase(file));
      await old.customStatement('SELECT 1'); // open + createAll @ v14
      // A tune imported from a known source (name stored in `from`)...
      await old.customStatement(
        'INSERT INTO tunes (name, "from", created_at) '
        "VALUES ('Imported', 'Paul Hardy Session Tunebook', 0)",
      );
      // ...one whose `from` is user-typed free text (not a source name)...
      await old.customStatement(
        'INSERT INTO tunes (name, "from", created_at) '
        "VALUES ('Learned', 'my teacher Mary', 0)",
      );
      // ...and one with no `from` at all.
      await old.customStatement(
        "INSERT INTO tunes (name, created_at) VALUES ('Original', 0)",
      );
      await old.close();

      final app = AppDatabase(NativeDatabase(file));
      final rows = await app
          .customSelect('SELECT name, "from", source FROM tunes ORDER BY name')
          .get();
      final bySource = {
        for (final r in rows)
          r.read<String>('name'): r.readNullable<String>('source'),
      };
      final byFrom = {
        for (final r in rows)
          r.read<String>('name'): r.readNullable<String>('from'),
      };

      // Provenance copied into source as the registry id.
      expect(bySource['Imported'], 'paulhardy');
      // Free text and null are not provenance — source stays null.
      expect(bySource['Learned'], isNull);
      expect(bySource['Original'], isNull);
      // `from` is left untouched by the migration.
      expect(byFrom['Imported'], 'Paul Hardy Session Tunebook');
      expect(byFrom['Learned'], 'my teacher Mary');

      await app.close();
    });
  });

  // Data-integrity test for the v15->v16 backfill: pre-v16, tunes imported from
  // sources that store the body with the key in a separate field (e.g.
  // thesession.org) cached an SVG rendered in C major. The migration clears the
  // stale cached SVG (abc_svg) for any tune whose ABC lacks a `K:` header line
  // so the detail view re-renders it with the right key, while leaving tunes
  // whose ABC already declares a key untouched.
  group('v15->v16 clears stale abc_svg for keyless ABC', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('tune_trove_svg');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    test('nulls cached SVG only when the ABC has no K: header', () async {
      final file = File('${tmpDir.path}/svg.sqlite');

      final old = v15.DatabaseAtV15(NativeDatabase(file));
      await old.customStatement('SELECT 1'); // open + createAll @ v15
      // Keyless body (thesession-style) with a cached SVG → should be cleared.
      await old.customStatement(
        'INSERT INTO tunes (name, abc, abc_svg, created_at) '
        "VALUES ('Keyless', '|:G>A B>G:|', '<svg>stale</svg>', 0)",
      );
      // ABC with a K: header line → SVG is valid, leave it.
      await old.customStatement(
        'INSERT INTO tunes (name, abc, abc_svg, created_at) '
        "VALUES ('Keyed', 'X:1' || char(10) || 'K:Dmaj' || char(10) || "
        "'ABcd', '<svg>good</svg>', 0)",
      );
      // ABC whose K: appears at the very start (no leading newline).
      await old.customStatement(
        'INSERT INTO tunes (name, abc, abc_svg, created_at) '
        "VALUES ('KeyedFirst', 'K:Gmaj' || char(10) || 'GABc', "
        "'<svg>good</svg>', 0)",
      );
      // No cached SVG yet → nothing to clear, stays null.
      await old.customStatement(
        'INSERT INTO tunes (name, abc, created_at) '
        "VALUES ('NoSvg', '|:abc:|', 0)",
      );
      await old.close();

      final app = AppDatabase(NativeDatabase(file));
      final rows = await app
          .customSelect('SELECT name, abc_svg FROM tunes ORDER BY name')
          .get();
      final bySvg = {
        for (final r in rows)
          r.read<String>('name'): r.readNullable<String>('abc_svg'),
      };

      // Keyless cached render is dropped so it re-renders with the real key.
      expect(bySvg['Keyless'], isNull);
      // Keyed renders are preserved.
      expect(bySvg['Keyed'], '<svg>good</svg>');
      expect(bySvg['KeyedFirst'], '<svg>good</svg>');
      // Already-null stays null.
      expect(bySvg['NoSvg'], isNull);

      await app.close();
    });
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
