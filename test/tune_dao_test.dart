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

  TunesCompanion tune(String name, {int? tsId, String? cloudId}) =>
      TunesCompanion(
        name: drift.Value(name),
        tsId: tsId == null ? const drift.Value.absent() : drift.Value(tsId),
        cloudId: cloudId == null ? const drift.Value.absent() : drift.Value(cloudId),
        genre: const drift.Value('irish'),
        createdAt: drift.Value(DateTime(2024)),
      );

  test('insertTune generates a cloudId when none is supplied', () async {
    final dao = db.tuneDao;
    final id = await dao.insertTune(tune('Cooley'));
    expect((await dao.getTune(id))?.cloudId, isNotNull);
  });

  test('insertTune preserves an explicit cloudId', () async {
    final dao = db.tuneDao;
    await dao.insertTune(tune('Cooley', cloudId: 'cid-1'));
    expect(await dao.getByCloudId('cid-1'), isNotNull);
  });

  test('getByTsId and getByName support dedupe lookups', () async {
    final dao = db.tuneDao;
    await dao.insertTune(tune('The Butterfly', tsId: 5));
    expect((await dao.getByTsId(5))?.name, 'The Butterfly');
    expect((await dao.getByName('The Butterfly'))?.tsId, 5);
    expect(await dao.getByTsId(999), isNull);
    expect(await dao.getByName('nope'), isNull);
  });

  test('updateTune writes changes', () async {
    final dao = db.tuneDao;
    final id = await dao.insertTune(tune('Old Name'));
    await dao.updateTune(
      TunesCompanion(id: drift.Value(id), name: const drift.Value('New Name')),
    );
    expect((await dao.getTune(id))?.name, 'New Name');
  });

  test('deleteTune removes the row', () async {
    final dao = db.tuneDao;
    final id = await dao.insertTune(tune('Doomed'));
    expect(await dao.deleteTune(id), 1);
    expect(await dao.getTune(id), isNull);
    expect(await dao.getAll(), isEmpty);
  });
}
