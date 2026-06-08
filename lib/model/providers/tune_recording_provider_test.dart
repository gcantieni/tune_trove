import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/tune_recording_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });


  Future<(int tuneId, int recId)> seedLinkedPair() async {
    final tuneId = await db.tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value('Cooley'),
        genre: const drift.Value('irish'),
        createdAt: drift.Value(DateTime(2024)),
      ),
    );
    final recId = await db.recordingDao.insertRecording(
      RecordingsCompanion(
        name: const drift.Value('Live at the pub'),
        url: const drift.Value('https://ex.com/1'),
        createdAt: drift.Value(DateTime(2024)),
      ),
    );
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recId);
    return (tuneId, recId);
  }

  test('linksForRecordingProvider streams the tunes on a recording', () async {
    final (tuneId, recId) = await seedLinkedPair();
    // Keep a listener alive so the autoDispose provider doesn't tear down
    // mid-read.
    container.listen(linksForRecordingProvider(recId), (_, _) {});
    final links = await container.read(linksForRecordingProvider(recId).future);
    expect(links, hasLength(1));
    expect(links.single.tune.id, tuneId);
  });

  test('recordingsForTuneProvider streams the recordings for a tune', () async {
    final (tuneId, recId) = await seedLinkedPair();
    container.listen(recordingsForTuneProvider(tuneId), (_, _) {});
    final links =
        await container.read(recordingsForTuneProvider(tuneId).future);
    expect(links, hasLength(1));
    expect(links.single.recording.id, recId);
  });

  test('providers emit empty lists when there are no links', () async {
    container.listen(linksForRecordingProvider(42), (_, _) {});
    container.listen(recordingsForTuneProvider(42), (_, _) {});
    expect(
      await container.read(linksForRecordingProvider(42).future),
      isEmpty,
    );
    expect(
      await container.read(recordingsForTuneProvider(42).future),
      isEmpty,
    );
  });
}
