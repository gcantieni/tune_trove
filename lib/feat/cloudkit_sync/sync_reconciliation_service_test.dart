import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';

void main() {
  late AppDatabase db;
  late SyncReconciliationService svc;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    svc = SyncReconciliationService(db);
  });
  tearDown(() => db.close());

  int ms(int year) => DateTime(year).millisecondsSinceEpoch;

  Future<void> apply({
    List<SyncUpsertEvent> upserts = const [],
    List<SyncDeleteEvent> deletions = const [],
  }) =>
      svc.applyFetched(FetchedChanges(upserts, deletions));

  SyncUpsertEvent up(String type, Map<String, dynamic> fields) =>
      SyncUpsertEvent(type, fields);

  group('base entity upserts', () {
    test('inserts a brand-new tune from remote', () async {
      await apply(upserts: [
        up('Tune', {
          'cloud_id': 'tune-1',
          'name': "Cooley's",
          'ts_id': 42,
          'type': 'reel',
          'created_at': ms(2023),
        }),
      ]);
      final row = await db.tuneDao.getByCloudId('tune-1');
      expect(row, isNotNull);
      expect(row!.name, "Cooley's");
      expect(row.tsId, 42);
      expect(row.type, TuneType.reel);
    });

    test('a locally-created tune adopts the remote cloud_id by ts_id '
        '(no duplicate)', () async {
      // Local tune with no cloud match but the same ts_id.
      await db.tuneDao.insertTune(
        TunesCompanion.insert(
          name: 'Local Cooley',
          createdAt: DateTime(2024),
          tsId: const drift.Value(42),
        ),
      );
      await apply(upserts: [
        up('Tune', {
          'cloud_id': 'remote-cid',
          'name': "Cooley's",
          'ts_id': 42,
          'created_at': ms(2020), // older than local -> keep local fields
        }),
      ]);
      final all = await db.tuneDao.getAll();
      expect(all, hasLength(1)); // adopted, not duplicated
      expect(all.single.cloudId, 'remote-cid');
      expect(all.single.name, 'Local Cooley'); // local fields preserved
    });

    test('a newer remote tune overwrites local fields', () async {
      await db.tuneDao.insertTune(
        TunesCompanion.insert(
          name: 'Old',
          createdAt: DateTime(2020),
          tsId: const drift.Value(7),
        ),
      );
      await apply(upserts: [
        up('Tune', {
          'cloud_id': 'c7',
          'name': 'New',
          'ts_id': 7,
          'modified_at': ms(2025),
        }),
      ]);
      final row = await db.tuneDao.getByTsId(7);
      expect(row!.name, 'New');
      expect(row.cloudId, 'c7');
    });

    test('a recording dedupes against an independently-created row by url',
        () async {
      await db.recordingDao.insertRecording(
        RecordingsCompanion.insert(
          name: 'Local',
          url: 'https://ex.com/a',
          createdAt: DateTime(2024),
        ),
      );
      await apply(upserts: [
        up('Recording', {
          'cloud_id': 'rec-1',
          'name': 'Remote',
          'url': 'https://ex.com/a',
          'created_at': ms(2020),
        }),
      ]);
      final all = await db.recordingDao.getAll();
      expect(all, hasLength(1));
      expect(all.single.cloudId, 'rec-1');
    });

    test('a set dedupes by name and inserts a source confirmation', () async {
      await db.setDao.insertSet(
        TuneSetsCompanion.insert(name: 'My Set', createdAt: DateTime(2024)),
      );
      await apply(upserts: [
        up('TuneSet', {
          'cloud_id': 'set-1',
          'name': 'My Set',
          'created_at': ms(2020),
        }),
        up('SourceConfirmation', {
          'cloud_id': 'sc-1',
          'source_id': 'thesession',
          'license': 'ODbL',
          'created_at': ms(2023),
        }),
      ]);
      expect((await db.setDao.getByName('My Set'))!.cloudId, 'set-1');
      expect(await db.sourceConfirmationDao.getByCloudId('sc-1'), isNotNull);
    });
  });

  group('join tables', () {
    test('links a tune and recording via their cloud ids', () async {
      await apply(upserts: [
        up('Tune', {'cloud_id': 't', 'name': 'T', 'created_at': ms(2023)}),
        up('Recording', {
          'cloud_id': 'r',
          'name': 'R',
          'url': 'u',
          'created_at': ms(2023),
        }),
        up('TuneRecording', {
          'cloud_id': 'tr',
          'tune_cloud_id': 't',
          'recording_cloud_id': 'r',
          'start_time': 1.5,
          'performed_key': 'ADor',
        }),
      ]);
      final link = await db.tuneRecordingDao.getByCloudId('tr');
      expect(link, isNotNull);
      expect(link!.startTime, 1.5);
      expect(link.performedKey, 'ADor');
    });

    test('skips a join whose base records are missing', () async {
      await apply(upserts: [
        up('TuneRecording', {
          'cloud_id': 'tr',
          'tune_cloud_id': 'missing',
          'recording_cloud_id': 'missing',
        }),
      ]);
      expect(await db.tuneRecordingDao.getByCloudId('tr'), isNull);
    });

    test('adds a tune to a set via cloud ids', () async {
      await apply(upserts: [
        up('TuneSet', {'cloud_id': 's', 'name': 'S', 'created_at': ms(2023)}),
        up('Tune', {'cloud_id': 't', 'name': 'T', 'created_at': ms(2023)}),
        up('SetTune', {
          'cloud_id': 'st',
          'set_cloud_id': 's',
          'tune_cloud_id': 't',
          'position': 0,
          'key': 'D',
        }),
      ]);
      expect(await db.setTuneDao.getByCloudId('st'), isNotNull);
    });
  });

  group('deletions', () {
    test('deletes a tune by cloud id', () async {
      await apply(upserts: [
        up('Tune', {'cloud_id': 'x', 'name': 'X', 'created_at': ms(2023)}),
      ]);
      expect(await db.tuneDao.getByCloudId('x'), isNotNull);

      await apply(deletions: [SyncDeleteEvent('Tune', 'x')]);
      expect(await db.tuneDao.getByCloudId('x'), isNull);
    });

    test('deleting an unknown cloud id is a no-op', () async {
      await apply(deletions: [SyncDeleteEvent('Tune', 'nope')]);
      expect(await db.tuneDao.getAll(), isEmpty);
    });
  });

  test('records without a cloud_id are ignored', () async {
    await apply(upserts: [
      up('Tune', {'name': 'No Cloud Id', 'created_at': ms(2023)}),
    ]);
    expect(await db.tuneDao.getAll(), isEmpty);
  });
}
