import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Future<int> insertSet(String name) => db.setDao.insertSet(
    TuneSetsCompanion.insert(name: name, createdAt: DateTime.now()),
  );

  Future<int> insertTune(String name) => db.tuneDao.insertTune(
    TunesCompanion.insert(name: name, createdAt: DateTime.now()),
  );

  group('SetTuneDao', () {
    test('addTuneToSet assigns sequential positions', () async {
      final setId = await insertSet('Set A');
      final tuneAId = await insertTune('Tune A');
      final tuneBId = await insertTune('Tune B');
      final tuneCId = await insertTune('Tune C');

      await db.setTuneDao.addTuneToSet(setId, tuneAId);
      await db.setTuneDao.addTuneToSet(setId, tuneBId);
      await db.setTuneDao.addTuneToSet(setId, tuneCId);

      final entries = await db.setTuneDao.watchTunesInSet(setId).first;

      expect(entries.length, 3);
      expect(entries[0].link.position, 0);
      expect(entries[1].link.position, 1);
      expect(entries[2].link.position, 2);
    });

    test('removeTuneFromSet removes the row', () async {
      final setId = await insertSet('Set B');
      final tuneId = await insertTune('Tune X');

      await db.setTuneDao.addTuneToSet(setId, tuneId);

      final before = await db.setTuneDao.watchTunesInSet(setId).first;
      expect(before.length, 1);

      final setTuneId = before.first.link.id;

      await db.setTuneDao.removeTuneFromSet(setTuneId);

      await expectLater(db.setTuneDao.watchTunesInSet(setId), emits(isEmpty));
    });

    test('watchTunesInSet orders by position', () async {
      final setId = await insertSet('Set C');
      final tuneAId = await insertTune('Alpha');
      final tuneBId = await insertTune('Beta');
      final tuneCId = await insertTune('Gamma');

      await db.setTuneDao.addTuneToSet(setId, tuneAId);
      await db.setTuneDao.addTuneToSet(setId, tuneBId);
      await db.setTuneDao.addTuneToSet(setId, tuneCId);

      final entries = await db.setTuneDao.watchTunesInSet(setId).first;

      expect(entries.map((e) => e.link.position).toList(), [0, 1, 2]);
      expect(entries.map((e) => e.tune.name).toList(), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
    });

    test('watchSetsForTune returns both sets the tune belongs to', () async {
      final setAId = await insertSet('Monday Set');
      final setBId = await insertSet('Friday Set');
      final tuneId = await insertTune('Shared Tune');

      await db.setTuneDao.addTuneToSet(setAId, tuneId);
      await db.setTuneDao.addTuneToSet(setBId, tuneId);

      final entries = await db.setTuneDao.watchSetsForTune(tuneId).first;

      expect(entries.length, 2);
      expect(
        entries.map((e) => e.tuneSet.name).toList(),
        containsAll(['Monday Set', 'Friday Set']),
      );
    });

    test('updateKey sets and clears per-set key override', () async {
      final setId = await insertSet('Key Set');
      final tuneId = await insertTune('Flying Clouds');

      await db.setTuneDao.addTuneToSet(setId, tuneId);
      final before = await db.setTuneDao.watchTunesInSet(setId).first;
      final setTuneId = before.first.link.id;
      expect(before.first.link.key, isNull);

      await db.setTuneDao.updateKey(setTuneId, 'Ador');
      final after = await db.setTuneDao.watchTunesInSet(setId).first;
      expect(after.first.link.key, 'Ador');

      await db.setTuneDao.updateKey(setTuneId, null);
      final cleared = await db.setTuneDao.watchTunesInSet(setId).first;
      expect(cleared.first.link.key, isNull);
    });

    test('reorderTune moves item and renumbers positions', () async {
      final setId = await insertSet('Reorder Set');
      final tuneAId = await insertTune('A');
      final tuneBId = await insertTune('B');
      final tuneCId = await insertTune('C');

      await db.setTuneDao.addTuneToSet(setId, tuneAId);
      await db.setTuneDao.addTuneToSet(setId, tuneBId);
      await db.setTuneDao.addTuneToSet(setId, tuneCId);

      await db.setTuneDao.reorderTune(setId, 2, 0);

      final entries = await db.setTuneDao.watchTunesInSet(setId).first;

      expect(entries.map((e) => e.tune.name).toList(), ['C', 'A', 'B']);
      expect(entries.map((e) => e.link.position).toList(), [0, 1, 2]);
    });
  });
}
