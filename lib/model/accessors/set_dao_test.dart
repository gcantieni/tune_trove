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
  tearDown(() => db.close());

  TuneSetsCompanion set(String name, {int? position, String? cloudId}) =>
      TuneSetsCompanion(
        name: drift.Value(name),
        position: position == null ? const drift.Value.absent() : drift.Value(position),
        cloudId: cloudId == null ? const drift.Value.absent() : drift.Value(cloudId),
        createdAt: drift.Value(DateTime(2024)),
      );

  test('insertSet auto-assigns sequential positions and a cloudId', () async {
    final dao = db.setDao;
    await dao.insertSet(set('A'));
    await dao.insertSet(set('B'));
    final all = await dao.getAll();
    expect(all.map((s) => s.name), ['A', 'B']);
    expect(all.map((s) => s.position), [0, 1]);
    expect(all.every((s) => s.cloudId != null), isTrue);
  });

  test('insertSet honours a supplied position and cloudId', () async {
    final dao = db.setDao;
    await dao.insertSet(set('X', position: 5, cloudId: 'cid-x'));
    final row = await dao.getByCloudId('cid-x');
    expect(row, isNotNull);
    expect(row!.position, 5);
  });

  test('getByName finds a set; getSet by id works', () async {
    final dao = db.setDao;
    final id = await dao.insertSet(set('Find Me'));
    expect((await dao.getByName('Find Me'))?.id, id);
    expect(await dao.getByName('absent'), isNull);
    expect((await dao.getSet(id))?.name, 'Find Me');
  });

  test('updateSet writes changes', () async {
    final dao = db.setDao;
    final id = await dao.insertSet(set('Old'));
    await dao.updateSet(
      TuneSetsCompanion(id: drift.Value(id), name: const drift.Value('New')),
    );
    expect((await dao.getSet(id))?.name, 'New');
  });

  test('deleteSet removes the row', () async {
    final dao = db.setDao;
    final id = await dao.insertSet(set('Doomed'));
    expect(await dao.deleteSet(id), 1);
    expect(await dao.getSet(id), isNull);
  });

  test('reorderSet renumbers positions contiguously', () async {
    final dao = db.setDao;
    await dao.insertSet(set('A')); // pos 0
    await dao.insertSet(set('B')); // pos 1
    await dao.insertSet(set('C')); // pos 2

    // Move the first item (A) to the end.
    await dao.reorderSet(0, 2);

    final names = (await dao.getAll()).map((s) => s.name).toList();
    expect(names, ['B', 'C', 'A']);
    expect((await dao.getAll()).map((s) => s.position), [0, 1, 2]);
  });
}
