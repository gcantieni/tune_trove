import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/backup/file_sync_transport.dart';
import 'package:tune_trove/feat/sync_core/sync_record_codec.dart';
import 'package:tune_trove/model/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    final tuneId = await db.tuneDao.insertTune(
      TunesCompanion.insert(name: "Cooley's", createdAt: DateTime(2024)),
    );
    final recId = await db.recordingDao.insertRecording(
      RecordingsCompanion.insert(
        name: 'A take',
        url: 'https://example.com/take',
        createdAt: DateTime(2024),
      ),
    );
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recId);
    final setId = await db.setDao.insertSet(
      TuneSetsCompanion.insert(name: 'My set', createdAt: DateTime(2024)),
    );
    await db.setTuneDao.addTuneToSet(setId, tuneId);
    await db.appSettingsDao.setValue('default_page', '/tune_list');
  }

  List<String> typesIn(List<Map<String, dynamic>> records) =>
      records.map((r) => r['recordType'] as String).toSet().toList();

  test('serializeAll includes every record type by default', () async {
    await seed();
    final records = await serializeAll(db, recordTypes: allSyncRecordTypes);
    final types = typesIn(records);
    expect(types, contains(tuneRecordType));
    expect(types, contains(recordingRecordType));
    expect(types, contains(tuneRecordingRecordType));
    expect(types, contains(tuneSetRecordType));
    expect(types, contains(setTuneRecordType));
    expect(types, contains(appSettingRecordType));
  });

  test('backupRecordTypes mirrors CloudKit (includes AppSetting)', () async {
    await seed();
    final records = await serializeAll(db, recordTypes: backupRecordTypes);
    final types = typesIn(records);
    expect(backupRecordTypes, allSyncRecordTypes);
    expect(types, contains(appSettingRecordType));
    expect(types, contains(tuneRecordType));
    expect(types, contains(tuneRecordingRecordType));
  });

  test('join records carry parent cloudIds', () async {
    await seed();
    final records = await serializeAll(db, recordTypes: allSyncRecordTypes);
    final join = records.firstWhere(
      (r) => r['recordType'] == tuneRecordingRecordType,
    );
    expect(join['tune_cloud_id'], isNotNull);
    expect(join['recording_cloud_id'], isNotNull);
  });

  test('recordsToFetchedChanges wraps records as upserts', () async {
    await seed();
    final records = await serializeAll(db, recordTypes: allSyncRecordTypes);
    final changes = recordsToFetchedChanges(records);
    expect(changes.upserts.length, records.length);
    expect(changes.deletions, isEmpty);
    expect(changes.upserts.first.recordType, isNotEmpty);
  });
}
