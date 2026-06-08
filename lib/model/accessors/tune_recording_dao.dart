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

  Future<TuneRecordingData?> getByCloudId(String cloudId) => (select(
    tuneRecording,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<TuneRecordingData?> getByTuneAndRecording(
    int tuneId,
    int recordingId,
  ) =>
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
    final linkCloudId = cloudId ?? generateUuid();
    return transaction(() async {
      final rowId = await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          startTime: Value(startTime),
          endTime: Value(endTime),
          performedKey: Value(performedKey),
          cloudId: Value(linkCloudId),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (rowId > 0) {
        await _bumpTuneModified(tuneId);
        attachedDatabase.notifyRowChanged(
          'TuneRecording',
          linkCloudId,
          deleted: false,
        );
      }
      return rowId;
    });
  }

  /// Insert a new tune and link it to the recording in a single transaction.
  Future<int> createTuneAndLink(TunesCompanion tune, int recordingId) {
    final tuneCloudId = tune.cloudId.present && tune.cloudId.value != null
        ? tune.cloudId.value!
        : generateUuid();
    final linkCloudId = generateUuid();
    return transaction(() async {
      final tuneId = await into(
        tunes,
      ).insert(tune.copyWith(cloudId: Value(tuneCloudId)));
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          cloudId: Value(linkCloudId),
        ),
      );
      attachedDatabase.notifyRowChanged('Tune', tuneCloudId, deleted: false);
      attachedDatabase.notifyRowChanged(
        'TuneRecording',
        linkCloudId,
        deleted: false,
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
    final recCloudId =
        recording.cloudId.present && recording.cloudId.value != null
        ? recording.cloudId.value!
        : generateUuid();
    final linkCloudId = generateUuid();
    return transaction(() async {
      final recordingId = await into(
        recordings,
      ).insert(recording.copyWith(cloudId: Value(recCloudId)));
      await into(tuneRecording).insert(
        TuneRecordingCompanion.insert(
          tuneId: tuneId,
          recordingId: recordingId,
          cloudId: Value(linkCloudId),
        ),
      );
      await _bumpTuneModified(tuneId);
      attachedDatabase.notifyRowChanged(
        'Recording',
        recCloudId,
        deleted: false,
      );
      attachedDatabase.notifyRowChanged(
        'TuneRecording',
        linkCloudId,
        deleted: false,
      );
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
      if (rows > 0) {
        await _bumpTuneModified(updated.tuneId);
        attachedDatabase.notifyRowChanged(
          'TuneRecording',
          updated.cloudId,
          deleted: false,
        );
      }
      return rows;
    });
  }

  Future<int> unlinkTuneFromRecording(int tuneId, int recordingId) {
    return transaction(() async {
      final existing = await getByTuneAndRecording(tuneId, recordingId);
      final rows =
          await (delete(tuneRecording)..where(
                (t) =>
                    t.tuneId.equals(tuneId) & t.recordingId.equals(recordingId),
              ))
              .go();
      if (rows > 0) {
        await _bumpTuneModified(tuneId);
        attachedDatabase.notifyRowChanged(
          'TuneRecording',
          existing?.cloudId,
          deleted: true,
        );
      }
      return rows;
    });
  }

  Future<int> _bumpTuneModified(int tuneId) async {
    final count = await (update(tunes)..where((t) => t.id.equals(tuneId)))
        .write(TunesCompanion(modifiedAt: Value(DateTime.now())));
    final tune = await (select(
      tunes,
    )..where((t) => t.id.equals(tuneId))).getSingleOrNull();
    attachedDatabase.notifyRowChanged('Tune', tune?.cloudId, deleted: false);
    return count;
  }

  /// The set of recording ids that have at least one linked tune. Streams so
  /// the Recordings "Has tune link" filter updates live as links change.
  Stream<Set<int>> watchLinkedRecordingIds() {
    return select(
      tuneRecording,
    ).watch().map((rows) => {for (final row in rows) row.recordingId});
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
