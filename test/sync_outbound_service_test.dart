import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/model/database.dart';

import 'support/fake_cloudkit_sync_service.dart';

void main() {
  late AppDatabase db;
  late FakeCloudKitSyncService fake;
  late SyncOutboundService svc;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    fake = FakeCloudKitSyncService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    svc = SyncOutboundService(
      db,
      fake,
      SyncReconciliationService(db),
      prefs,
    );
  });
  tearDown(() => db.close());

  Future<int> seedTune(String name) => db.tuneDao.insertTune(
        TunesCompanion.insert(
          name: name,
          createdAt: DateTime(2024),
          tsId: const drift.Value(11),
          type: const drift.Value(null),
        ),
      );

  group('serializeByCloudId', () {
    test('serializes a tune', () async {
      await seedTune('Cooley');
      final cid = (await db.tuneDao.getAll()).single.cloudId!;
      final map = await svc.serializeByCloudId('Tune', cid);
      expect(map, isNotNull);
      expect(map!['recordType'], 'Tune');
      expect(map['name'], 'Cooley');
      expect(map['ts_id'], 11);
      expect(map['created_at'], isA<int>());
    });

    test('serializes a tune-recording join with parent cloud ids', () async {
      final tuneId = await seedTune('T');
      final recId = await db.recordingDao.insertRecording(
        RecordingsCompanion.insert(
          name: 'R',
          url: 'u',
          createdAt: DateTime(2024),
        ),
      );
      await db.tuneRecordingDao
          .linkTuneToRecording(tuneId, recId, startTime: 2.0);
      final tune = await db.tuneDao.getTune(tuneId);
      final link = (await db.tuneRecordingDao.getAll()).single;

      final map = await svc.serializeByCloudId('TuneRecording', link.cloudId!);
      expect(map, isNotNull);
      expect(map!['tune_cloud_id'], tune!.cloudId);
      expect(map['start_time'], 2.0);
    });

    test('serializes a set, a set-tune link, and a source confirmation',
        () async {
      final setId = await db.setDao.insertSet(
        TuneSetsCompanion.insert(name: 'S', createdAt: DateTime(2024)),
      );
      final tuneId = await seedTune('T');
      await db.setTuneDao.addTuneToSet(setId, tuneId, key: 'D');
      await db.sourceConfirmationDao.confirm('thesession', 'ODbL');

      final setCid = (await db.setDao.getAll()).single.cloudId!;
      final stCid = (await db.setTuneDao.getAll()).single.cloudId!;
      final scCid = (await db.sourceConfirmationDao.getAll()).single.cloudId!;

      expect((await svc.serializeByCloudId('TuneSet', setCid))!['name'], 'S');
      final st = await svc.serializeByCloudId('SetTune', stCid);
      expect(st!['set_cloud_id'], setCid);
      expect(st['key'], 'D');
      final sc = await svc.serializeByCloudId('SourceConfirmation', scCid);
      expect(sc!['source_id'], 'thesession');
    });

    test('serializes a source ranking and an app setting', () async {
      await db.sourceRankingsDao.appendSource('thesession');
      await db.appSettingsDao.setValue('theme', 'dark');

      final srCid = (await db.sourceRankingsDao.getAll()).single.cloudId!;
      final asCid = (await db.appSettingsDao.getAll()).single.cloudId!;

      expect(
        (await svc.serializeByCloudId('SourceRanking', srCid))!['source_id'],
        'thesession',
      );
      final as = await svc.serializeByCloudId('AppSetting', asCid);
      expect(as!['key'], 'theme');
      expect(as['value'], 'dark');
    });

    test('returns null for a missing row and an unknown type', () async {
      expect(await svc.serializeByCloudId('Tune', 'absent'), isNull);
      expect(await svc.serializeByCloudId('Bogus', 'x'), isNull);
    });
  });

  group('syncNow', () {
    test('initializes, reconciles fetched changes, backfills and sends',
        () async {
      await seedTune('Local');
      // Remote hands back a brand-new tune to reconcile in.
      fake.fetched = FetchedChanges([
        SyncUpsertEvent('Tune', {
          'cloud_id': 'remote-1',
          'name': 'Remote Tune',
          'created_at': DateTime(2023).millisecondsSinceEpoch,
        }),
      ], const []);

      final result = await svc.syncNow();

      expect(fake.initializeCalls, 1);
      expect(fake.sendCalls, 1);
      expect(result, isA<SendResult>());
      // Reconciliation ran.
      expect(await db.tuneDao.getByCloudId('remote-1'), isNotNull);
      // First sync backfills: every local row was staged.
      expect(fake.stagedRecords, hasLength(1));
      expect(fake.stagedRecords.single, isNotEmpty);
      expect(prefs.getBool('sync_initial_push_done'), isTrue);
    });

    test('does not re-stage everything once backfilled', () async {
      await seedTune('Local');
      await svc.syncNow(); // backfill
      await svc.syncNow(); // incremental: no full re-stage
      expect(fake.stagedRecords, hasLength(1));
      expect(fake.sendCalls, 2);
    });

    test('fullPush re-stages even after backfill', () async {
      await seedTune('Local');
      await svc.syncNow(); // backfill
      await svc.syncNow(fullPush: true);
      expect(fake.stagedRecords, hasLength(2));
    });
  });
}
