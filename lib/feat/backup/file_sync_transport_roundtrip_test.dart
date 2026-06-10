// Test co-located in lib/ (no test/ tree), so the analyzer cannot treat it
// as a test for @visibleForTesting purposes.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tune_trove/feat/backup/file_sync_transport.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/feat/sync_core/sync_record_codec.dart';
import 'package:tune_trove/model/database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath, this.tempPath);
  final String docsPath;
  final String tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

AppDatabase _memDb() => AppDatabase(
  drift.DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocs;
  late Directory tempTmp;
  late Directory sourceDir;

  setUp(() {
    tempDocs = Directory.systemTemp.createTempSync('backup_docs');
    tempTmp = Directory.systemTemp.createTempSync('backup_tmp');
    sourceDir = Directory.systemTemp.createTempSync('backup_src');
    PathProviderPlatform.instance = _FakePathProvider(
      tempDocs.path,
      tempTmp.path,
    );
  });
  tearDown(() {
    tempDocs.deleteSync(recursive: true);
    tempTmp.deleteSync(recursive: true);
    sourceDir.deleteSync(recursive: true);
  });

  test(
    'export then import restores library and audio into a fresh db',
    () async {
      // A local audio file the recording points at.
      final audioBytes = List<int>.generate(64, (i) => i % 256);
      final audioFile = File(p.join(sourceDir.path, 'take.m4a'))
        ..writeAsBytesSync(audioBytes);

      final src = _memDb();
      final tuneId = await src.tuneDao.insertTune(
        TunesCompanion.insert(name: "Cooley's", createdAt: DateTime(2024)),
      );
      final recId = await src.recordingDao.insertRecording(
        RecordingsCompanion.insert(
          name: 'A take',
          url: 'file://${audioFile.path}',
          createdAt: DateTime(2024),
        ),
      );
      await src.tuneRecordingDao.linkTuneToRecording(tuneId, recId);
      final setId = await src.setDao.insertSet(
        TuneSetsCompanion.insert(name: 'My set', createdAt: DateTime(2024)),
      );
      await src.setTuneDao.addTuneToSet(setId, tuneId);

      final records = await serializeAll(src, recordTypes: backupRecordTypes);
      final zipBytes = await FileSyncTransport(src).buildArchive(records);
      await src.close();

      // Import into a brand-new database.
      final dest = _memDb();
      final recon = SyncReconciliationService(dest);
      final changes = await FileSyncTransport(dest, source: zipBytes).pull();
      await recon.applyFetched(changes);

      final tunes = await dest.tuneDao.getAll();
      final recs = await dest.recordingDao.getAll();
      final sets = await dest.setDao.getAll();
      expect(tunes.length, 1);
      expect(recs.length, 1);
      expect(sets.length, 1);
      expect((await dest.tuneRecordingDao.getAll()).length, 1);
      expect((await dest.setTuneDao.getAll()).length, 1);

      // Audio was materialized locally and the url rewritten to point at it.
      final restored = recs.single;
      expect(restored.url, startsWith('file://'));
      final localPath = restored.url.substring('file://'.length);
      expect(File(localPath).existsSync(), isTrue);
      expect(File(localPath).readAsBytesSync(), audioBytes);

      // Re-importing the same archive is a no-op (idempotent merge).
      final changes2 = await FileSyncTransport(dest, source: zipBytes).pull();
      await recon.applyFetched(changes2);
      expect((await dest.tuneDao.getAll()).length, 1);
      expect((await dest.recordingDao.getAll()).length, 1);

      await dest.close();
    },
  );

  test(
    'malformed bytes throw BackupFormatException, valid archive imports',
    () async {
      final src = _memDb();
      final records = await serializeAll(src, recordTypes: backupRecordTypes);
      final bytes = await FileSyncTransport(src).buildArchive(records);
      await src.close();

      final dest = _memDb();
      expect(
        () => FileSyncTransport(dest, source: const [1, 2, 3]).pull(),
        throwsA(isA<BackupFormatException>()),
      );
      // A well-formed (empty-library) archive still parses cleanly.
      final changes = await FileSyncTransport(dest, source: bytes).pull();
      expect(changes.deletions, isEmpty);
      await dest.close();
    },
  );
}
