import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database.dart';

TunesCompanion _tune(String name) => TunesCompanion(
  name: drift.Value(name),
  createdAt: drift.Value(DateTime.now()),
);

RecordingsCompanion _recording(String name) => RecordingsCompanion(
  name: drift.Value(name),
  url: drift.Value('app-data:$name.m4a'),
  createdAt: drift.Value(DateTime.now()),
);

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

  tearDown(() async {
    await db.close();
  });

  test('linkTuneToRecording inserts link and bumps tune modifiedAt', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('The Morning Dew'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_01'));

    final rowId = await db.tuneRecordingDao.linkTuneToRecording(
      tuneId,
      recordingId,
    );

    expect(rowId, greaterThan(0));

    final tune = await (db.select(
      db.tunes,
    )..where((t) => t.id.equals(tuneId))).getSingle();
    expect(tune.modifiedAt, isNotNull);
  });

  test('linkTuneToRecording duplicate is idempotent', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('The Morning Dew'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_01'));

    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recordingId);
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recordingId);

    final rows = await db.select(db.tuneRecording).get();
    expect(rows.length, equals(1));
  });

  test('createTuneAndLink creates tune and link atomically', () async {
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_02'));

    final tuneId = await db.tuneRecordingDao.createTuneAndLink(
      _tune('The Kesh Jig'),
      recordingId,
    );

    expect(tuneId, greaterThan(0));

    final tune = await (db.select(
      db.tunes,
    )..where((t) => t.id.equals(tuneId))).getSingleOrNull();
    expect(tune, isNotNull);
    expect(tune?.name, equals('The Kesh Jig'));

    final links = await db.select(db.tuneRecording).get();
    expect(links.length, equals(1));
    expect(links.first.tuneId, equals(tuneId));
    expect(links.first.recordingId, equals(recordingId));
  });

  test(
    'createRecordingAndLink creates recording and link and bumps tune modifiedAt',
    () async {
      final tuneId = await db.into(db.tunes).insert(_tune("Cooley's Reel"));

      final recordingId = await db.tuneRecordingDao.createRecordingAndLink(
        _recording('session_03'),
        tuneId,
      );

      expect(recordingId, greaterThan(0));

      final recording = await (db.select(
        db.recordings,
      )..where((r) => r.id.equals(recordingId))).getSingleOrNull();
      expect(recording, isNotNull);

      final links = await db.select(db.tuneRecording).get();
      expect(links.length, equals(1));
      expect(links.first.tuneId, equals(tuneId));
      expect(links.first.recordingId, equals(recordingId));

      final tune = await (db.select(
        db.tunes,
      )..where((t) => t.id.equals(tuneId))).getSingle();
      expect(tune.modifiedAt, isNotNull);
    },
  );

  test('unlinkTuneFromRecording removes link and bumps modifiedAt', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('The Silver Spear'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_04'));

    // Insert the link directly (bypasses DAO) so modifiedAt stays null.
    await db
        .into(db.tuneRecording)
        .insert(
          TuneRecordingCompanion.insert(
            tuneId: tuneId,
            recordingId: recordingId,
          ),
        );
    final tuneBefore = await (db.select(
      db.tunes,
    )..where((t) => t.id.equals(tuneId))).getSingle();
    expect(tuneBefore.modifiedAt, isNull);

    final rows = await db.tuneRecordingDao.unlinkTuneFromRecording(
      tuneId,
      recordingId,
    );

    expect(rows, equals(1));

    final remaining = await db.select(db.tuneRecording).get();
    expect(remaining, isEmpty);

    final tuneAfter = await (db.select(
      db.tunes,
    )..where((t) => t.id.equals(tuneId))).getSingle();
    expect(tuneAfter.modifiedAt, isNotNull);
  });

  test('unlinkTuneFromRecording on missing pair returns 0', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('The Silver Spear'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_05'));

    final rows = await db.tuneRecordingDao.unlinkTuneFromRecording(
      tuneId,
      recordingId,
    );

    expect(rows, equals(0));
  });

  test('watchLinksForTune emits LinkedRecording after insert', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('Rakish Paddy'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_06'));
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recordingId);

    final stream = db.tuneRecordingDao.watchLinksForTune(tuneId);

    await expectLater(
      stream,
      emits(
        isA<List<LinkedRecording>>()
            .having((list) => list.length, 'length', 1)
            .having(
              (list) => list.first.recording.id,
              'recording.id',
              recordingId,
            )
            .having((list) => list.first.link.tuneId, 'link.tuneId', tuneId),
      ),
    );
  });

  test('linkTuneToRecording stores performedKey', () async {
    final tuneId = await db
        .into(db.tunes)
        .insert(_tune('The Humours of Tulla'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_08'));

    await db.tuneRecordingDao.linkTuneToRecording(
      tuneId,
      recordingId,
      performedKey: 'Edor',
    );

    final links = await db.select(db.tuneRecording).get();
    expect(links.length, 1);
    expect(links.first.performedKey, 'Edor');
  });

  test('updateLink persists performedKey change', () async {
    final tuneId = await db
        .into(db.tunes)
        .insert(_tune('The Humours of Tulla'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_09'));
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recordingId);

    final link = (await db.select(db.tuneRecording).get()).first;
    await db.tuneRecordingDao.updateLink(
      link.copyWith(performedKey: const drift.Value('G')),
    );

    final updated = (await db.select(db.tuneRecording).get()).first;
    expect(updated.performedKey, 'G');
  });

  test('watchLinksForRecording emits RecordedTune after insert', () async {
    final tuneId = await db.into(db.tunes).insert(_tune('Rakish Paddy'));
    final recordingId = await db
        .into(db.recordings)
        .insert(_recording('session_07'));
    await db.tuneRecordingDao.linkTuneToRecording(tuneId, recordingId);

    final stream = db.tuneRecordingDao.watchLinksForRecording(recordingId);

    await expectLater(
      stream,
      emits(
        isA<List<RecordedTune>>()
            .having((list) => list.length, 'length', 1)
            .having((list) => list.first.tune.id, 'tune.id', tuneId)
            .having(
              (list) => list.first.link.recordingId,
              'link.recordingId',
              recordingId,
            ),
      ),
    );
  });
}
