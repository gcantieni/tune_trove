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
  Future<int> insertRecording(RecordingsCompanion recording) async {
    final cloudId = recording.cloudId.present && recording.cloudId.value != null
        ? recording.cloudId.value!
        : generateUuid();
    final id = await into(
      recordings,
    ).insert(recording.copyWith(cloudId: Value(cloudId)));
    attachedDatabase.notifyRowChanged('Recording', cloudId, deleted: false);
    return id;
  }

  // read static
  Future<List<Recording>> getAll() => select(recordings).get();
  Future<Recording?> getRecording(int id) =>
      (select(recordings)..where((r) => r.id.equals(id))).getSingleOrNull();
  Future<Recording?> getByCloudId(String cloudId) => (select(
    recordings,
  )..where((r) => r.cloudId.equals(cloudId))).getSingleOrNull();
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
  Future<int> updateRecording(Recording updatedRecording) async {
    final count =
        await (update(
          recordings,
        )..where((t) => t.id.equals(updatedRecording.id))).write(
          updatedRecording.toCompanion(
            true,
          ), // coalesces Recording into RecordingCompanion
        );
    attachedDatabase.notifyRowChanged(
      'Recording',
      updatedRecording.cloudId,
      deleted: false,
    );
    return count;
  }

  // delete
  Future<int> deleteRecording(int id) async {
    final row = await getRecording(id);
    final count = await (delete(
      recordings,
    )..where((r) => r.id.equals(id))).go();
    attachedDatabase.notifyRowChanged('Recording', row?.cloudId, deleted: true);
    return count;
  }
}
