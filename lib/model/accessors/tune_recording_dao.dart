import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/recordings.dart';
import 'package:tune_trove/model/tables/tune_recording.dart';
import 'package:tune_trove/model/tables/tunes.dart';

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
  Future<int> linkTuneToRecording(
    int tuneId,
    int recordingId, {
    double? startTime,
    double? endTime,
    String? performedKey,
  }) {
    return transaction(() async {
      final rowId = await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          startTime: Value(startTime),
          endTime: Value(endTime),
          performedKey: Value(performedKey),
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
      final tuneId = await into(tunes).insert(tune);
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(tuneId: tuneId, recordingId: recordingId),
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
      final recordingId = await into(recordings).insert(recording);
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(tuneId: tuneId, recordingId: recordingId),
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
