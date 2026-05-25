import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/recordings.dart';
import 'package:tune_trove/util/uuid.dart';

part 'recording_dao.g.dart';

@DriftAccessor(tables: [Recordings])
class RecordingDao extends DatabaseAccessor<AppDatabase>
    with _$RecordingDaoMixin {
  RecordingDao(super.db);

  // create
  Future<int> insertRecording(RecordingsCompanion recording) {
    final companion = recording.cloudId.present
        ? recording
        : recording.copyWith(cloudId: Value(generateUuid()));
    return into(recordings).insert(companion);
  }

  // read static
  Future<List<Recording>> getAll() => select(recordings).get();
  Future<Recording?> getRecording(int id) =>
      (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull();
  Future<Recording?> getByCloudId(String cloudId) =>
      (select(recordings)..where((r) => r.cloudId.equals(cloudId)))
          .getSingleOrNull();
  Future<int?> findIdByUrl(String url) async {
    final row =
        await (select(recordings)
              ..where((r) => r.url.equals(url))
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  // Dedupe lookup: url is the natural cross-device identifier for a recording.
  Future<Recording?> getByUrl(String url) =>
      (select(recordings)
            ..where((r) => r.url.equals(url))
            ..limit(1))
          .getSingleOrNull();

  // read reactive
  Stream<List<Recording>> watchAllRecordings() => select(recordings).watch();
  Stream<Recording?> watchRecording(int id) =>
      (select(recordings)..where((r) => r.id.equals(id))).watchSingleOrNull();

  // update
  Future<int> updateRecording(Recording updatedRecording) {
    return (update(
      recordings,
    )..where((t) => t.id.equals(updatedRecording.id))).write(
      updatedRecording.toCompanion(
        true,
      ), // coalesces Recording into RecordingCompanion
    );
  }

  // delete
  Future deleteRecording(int id) =>
      (delete(recordings)..where((r) => r.id.equals(id))).go();
}
