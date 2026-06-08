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

  test('confirm inserts a row and is idempotent', () async {
    final dao = db.sourceConfirmationDao;
    await dao.confirm('oneills_1001', 'GNU GPL');
    await dao.confirm('oneills_1001', 'GNU GPL'); // no-op second time

    final all = await dao.getAll();
    expect(all, hasLength(1));
    expect(all.single.sourceId, 'oneills_1001');
    expect(all.single.license, 'GNU GPL');
    expect(all.single.cloudId, isNotNull);
  });

  test(
    'revoke removes the row; revoking a missing source is a no-op',
    () async {
      final dao = db.sourceConfirmationDao;
      await dao.revoke('not_there'); // no throw
      await dao.confirm('thesession', 'ODbL 1.0');
      await dao.revoke('thesession');
      expect(await dao.getAll(), isEmpty);
    },
  );

  test('getBySourceId and getByCloudId look rows up', () async {
    final dao = db.sourceConfirmationDao;
    await dao.confirm('norbeck', 'free');
    final row = await dao.getBySourceId('norbeck');
    expect(row, isNotNull);
    expect(await dao.getByCloudId(row!.cloudId!), isNotNull);
    expect(await dao.getBySourceId('absent'), isNull);
    expect(await dao.getByCloudId('absent'), isNull);
  });

  test('watchConfirmedIds emits the live set of confirmed ids', () async {
    final dao = db.sourceConfirmationDao;
    await dao.confirm('a', 'l');
    await dao.confirm('b', 'l');
    expect(await dao.watchConfirmedIds().first, {'a', 'b'});
  });

  test('insertFromRemote and adoptRemote round-trip', () async {
    final dao = db.sourceConfirmationDao;
    await dao.insertFromRemote(
      sourceId: 'remote_src',
      cloudId: 'cloud-1',
      license: 'CC0',
      createdAt: DateTime(2020),
    );
    final row = await dao.getByCloudId('cloud-1');
    expect(row, isNotNull);
    expect(row!.sourceId, 'remote_src');

    await dao.adoptRemote(row.id, cloudId: 'cloud-2', license: 'CC-BY');
    expect(await dao.getByCloudId('cloud-1'), isNull);
    final adopted = await dao.getByCloudId('cloud-2');
    expect(adopted!.license, 'CC-BY');
  });

  test('deleteByCloudId removes the matching row', () async {
    final dao = db.sourceConfirmationDao;
    await dao.insertFromRemote(
      sourceId: 's',
      cloudId: 'c',
      createdAt: DateTime(2021),
    );
    await dao.deleteByCloudId('c');
    expect(await dao.getAll(), isEmpty);
  });
}
