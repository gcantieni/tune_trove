import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/recordings.dart';
import 'package:tune_trove/model/tables/tune_recording.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/util/uuid.dart';

part 'tune_recording_dao.g.dart';

/// A row of `tune_recording` joined with its referenced tune.
typedef RecordedTune = ({Tune tune, TuneRecordingData link});

/// A row of `tune_recording` joined with its referenced recording.
typedef LinkedRecording = ({Recording recording, TuneRecordingData link});

@DriftAccessor(tables: [TuneRecording, Tunes, Recordings])
class TuneRecordingDao extends DatabaseAccessor<AppDatabase>
    with _$TuneRecordingDaoMixin {
  TuneRecordingDao(super.db);

  /// Re-linking the same (tune, recording) pair is a silent no-op
  /// thanks to the composite PK and insertOrIgnore mode. Bumps the
  /// tune's modifiedAt on a real insert so it surfaces in "recently
  /// updated" sorts.
  Future<List<TuneRecordingData>> getAll() => select(tuneRecording).get();

  Future<TuneRecordingData?> getByCloudId(String cloudId) =>
      (select(tuneRecording)..where((t) => t.cloudId.equals(cloudId)))
          .getSingleOrNull();

  Future<TuneRecordingData?> getByTuneAndRecording(int tuneId, int recordingId) =>
      (select(tuneRecording)..where(
            (t) => t.tuneId.equals(tuneId) & t.recordingId.equals(recordingId),
          ))
          .getSingleOrNull();

  Future<int> linkTuneToRecording(
    int tuneId,
    int recordingId, {
    double? startTime,
    double? endTime,
    String? performedKey,
    String? cloudId,
  }) {
    return transaction(() async {
      final rowId = await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          startTime: Value(startTime),
          endTime: Value(endTime),
          performedKey: Value(performedKey),
          cloudId: Value(cloudId ?? generateUuid()),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (rowId > 0) await _bumpTuneModified(tuneId);
      return rowId;
    });
  }

  /// Insert a new tune and link it to the recording in a single transaction.
  Future<int> createTuneAndLink(TunesCompanion tune, int recordingId) {
    return transaction(() async {
      final tuneId = await into(tunes).insert(
        tune.cloudId.present ? tune : tune.copyWith(cloudId: Value(generateUuid())),
      );
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          cloudId: Value(generateUuid()),
        ),
      );
      return tuneId;
    });
  }

  /// Insert a new recording and link it to the tune in a single transaction.
  /// Bumps the tune's modifiedAt — the user just added a recording to it.
  Future<int> createRecordingAndLink(
    RecordingsCompanion recording,
    int tuneId,
  ) {
    return transaction(() async {
      final recordingId = await into(recordings).insert(
        recording.cloudId.present
            ? recording
            : recording.copyWith(cloudId: Value(generateUuid())),
      );
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          cloudId: Value(generateUuid()),
        ),
      );
      await _bumpTuneModified(tuneId);
      return recordingId;
    });
  }

  Future<int> updateLink(TuneRecordingData updated) {
    return transaction(() async {
      final rows =
          await (update(tuneRecording)..where(
                (t) =>
                    t.tuneId.equals(updated.tuneId) &
                    t.recordingId.equals(updated.recordingId),
              ))
              .write(updated.toCompanion(true));
      if (rows > 0) await _bumpTuneModified(updated.tuneId);
      return rows;
    });
  }

  Future<int> unlinkTuneFromRecording(int tuneId, int recordingId) {
    return transaction(() async {
      final rows =
          await (delete(tuneRecording)..where(
                (t) =>
                    t.tuneId.equals(tuneId) & t.recordingId.equals(recordingId),
              ))
              .go();
      if (rows > 0) await _bumpTuneModified(tuneId);
      return rows;
    });
  }

  Future<int> _bumpTuneModified(int tuneId) {
    return (update(tunes)..where((t) => t.id.equals(tuneId))).write(
      TunesCompanion(modifiedAt: Value(DateTime.now())),
    );
  }

  Stream<List<RecordedTune>> watchLinksForRecording(int recordingId) {
    final query = select(tunes).join([
      innerJoin(tuneRecording, tuneRecording.tuneId.equalsExp(tunes.id)),
    ])..where(tuneRecording.recordingId.equals(recordingId));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (
              tune: row.readTable(tunes),
              link: row.readTable(tuneRecording),
            ),
          )
          .toList(),
    );
  }

  Stream<List<LinkedRecording>> watchLinksForTune(int tuneId) {
    final query = select(recordings).join([
      innerJoin(
        tuneRecording,
        tuneRecording.recordingId.equalsExp(recordings.id),
      ),
    ])..where(tuneRecording.tuneId.equals(tuneId));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (
              recording: row.readTable(recordings),
              link: row.readTable(tuneRecording),
            ),
          )
          .toList(),
    );
  }
}
