import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/recording_dao.dart';
import 'package:tune_trove/model/accessors/set_dao.dart';
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
  tearDown(() async {
    await db.close();
  });

  group('RecordingDao', () {
    test('insertRecording and getRecording', () async {
      final dao = RecordingDao(db);

      const name = 'Session at Crane Bar';
      const url = 'app-data:recordings/crane_bar.m4a';
      const performers = 'Trad Session';
      final createdAt = DateTime.now();

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value(name),
          url: const drift.Value(url),
          performers: const drift.Value(performers),
          createdAt: drift.Value(createdAt),
        ),
      );

      final all = await dao.getAll();
      expect(all.length, 1);
      final id = all.first.id;

      final recording = await dao.getRecording(id);
      expect(recording, isNotNull);
      expect(recording?.name, name);
      expect(recording?.url, url);
      expect(recording?.performers, performers);
      expect(recording?.modifiedAt, isNull);
    });

    test('getAll returns all inserted recordings', () async {
      final dao = RecordingDao(db);
      final now = DateTime.now();

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Recording A'),
          url: const drift.Value('app-data:a.m4a'),
          createdAt: drift.Value(now),
        ),
      );
      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Recording B'),
          url: const drift.Value('app-data:b.m4a'),
          createdAt: drift.Value(now),
        ),
      );

      final all = await dao.getAll();
      expect(all.length, 2);
      expect(
        all.map((r) => r.name),
        containsAll(['Recording A', 'Recording B']),
      );
    });

    test('updateRecording persists changes', () async {
      final dao = RecordingDao(db);
      final now = DateTime.now();

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Original Name'),
          url: const drift.Value('app-data:original.m4a'),
          createdAt: drift.Value(now),
        ),
      );

      final inserted = (await dao.getAll()).first;

      final updated = inserted.copyWith(
        name: 'Updated Name',
        modifiedAt: drift.Value(now),
      );
      await dao.updateRecording(updated);

      final fetched = await dao.getRecording(inserted.id);
      expect(fetched?.name, 'Updated Name');
      expect(fetched?.modifiedAt, isNotNull);
    });

    test('deleteRecording removes the recording', () async {
      final dao = RecordingDao(db);

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('To Delete'),
          url: const drift.Value('app-data:delete_me.m4a'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      final id = (await dao.getAll()).first.id;
      expect(await dao.getRecording(id), isNotNull);

      await dao.deleteRecording(id);

      expect(await dao.getRecording(id), isNull);
      expect(await dao.getAll(), isEmpty);
    });

    test('watchAllRecordings emits on insert', () async {
      final dao = RecordingDao(db);
      final now = DateTime.now();

      final stream = dao.watchAllRecordings();

      final future = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          isA<List<Recording>>().having((list) => list.length, 'length', 1),
        ]),
      );

      await Future.delayed(Duration.zero);

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Watched Recording'),
          url: const drift.Value('app-data:watched.m4a'),
          createdAt: drift.Value(now),
        ),
      );

      await future;
    });

    test('findIdByUrl returns id for matching url', () async {
      final dao = RecordingDao(db);
      final now = DateTime.now();

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Target'),
          url: const drift.Value('app-data:target.m4a'),
          createdAt: drift.Value(now),
        ),
      );
      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Other'),
          url: const drift.Value('app-data:other.m4a'),
          createdAt: drift.Value(now),
        ),
      );

      final targetId = (await dao.getAll())
          .firstWhere((r) => r.url == 'app-data:target.m4a')
          .id;

      expect(await dao.findIdByUrl('app-data:target.m4a'), targetId);
      expect(await dao.findIdByUrl('app-data:missing.m4a'), isNull);
    });

    test('watchRecording emits on update', () async {
      final dao = RecordingDao(db);
      final now = DateTime.now();

      await dao.insertRecording(
        RecordingsCompanion(
          name: const drift.Value('Before Update'),
          url: const drift.Value('app-data:before.m4a'),
          createdAt: drift.Value(now),
        ),
      );

      final id = (await dao.getAll()).first.id;
      final stream = dao.watchRecording(id);

      expectLater(
        stream,
        emitsInOrder([
          isA<Recording>().having((r) => r.name, 'name', 'Before Update'),
          isA<Recording>().having((r) => r.name, 'name', 'After Update'),
        ]),
      );

      final current = (await dao.getAll()).first;
      await dao.updateRecording(current.copyWith(name: 'After Update'));
    });
  });

  group('SetDao', () {
    test('insertSet and watchAllSets emits on insert', () async {
      final dao = SetDao(db);
      final now = DateTime.now();

      final stream = dao.watchAllSets();

      final future = expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          isA<List<TuneSet>>().having((list) => list.length, 'length', 1),
        ]),
      );

      await Future.delayed(Duration.zero);

      await dao.insertSet(
        TuneSetsCompanion(
          name: const drift.Value('Monday Night Set'),
          createdAt: drift.Value(now),
        ),
      );

      await future;
    });

    test('watchSet emits for the correct set', () async {
      final dao = SetDao(db);
      final now = DateTime.now();

      final id = await dao.insertSet(
        TuneSetsCompanion(
          name: const drift.Value('Watch Me'),
          createdAt: drift.Value(now),
        ),
      );

      final stream = dao.watchSet(id);

      expectLater(
        stream,
        emitsInOrder([
          isA<TuneSet>().having((s) => s.name, 'name', 'Watch Me'),
        ]),
      );
    });

    test('updateSet persists changes', () async {
      final dao = SetDao(db);
      final now = DateTime.now();

      final id = await dao.insertSet(
        TuneSetsCompanion(
          name: const drift.Value('Original Set'),
          createdAt: drift.Value(now),
        ),
      );

      await dao.updateSet(
        TuneSetsCompanion(
          id: drift.Value(id),
          name: const drift.Value('Renamed Set'),
          createdAt: drift.Value(now),
          modifiedAt: drift.Value(now),
        ),
      );

      final updated = await dao.watchSet(id).first;
      expect(updated?.name, 'Renamed Set');
      expect(updated?.modifiedAt, isNotNull);
    });

    test('deleteSet removes the set', () async {
      final dao = SetDao(db);
      final now = DateTime.now();

      final id = await dao.insertSet(
        TuneSetsCompanion(
          name: const drift.Value('To Delete'),
          createdAt: drift.Value(now),
        ),
      );

      final before = await dao.watchSet(id).first;
      expect(before, isNotNull);

      await dao.deleteSet(id);

      final after = await dao.watchSet(id).first;
      expect(after, isNull);
    });
  });
}
