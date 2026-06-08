import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/source_rankings_dao.dart';
import 'package:tune_trove/model/database.dart';

void main() {
  late AppDatabase db;
  late SourceRankingsDao dao;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dao = db.sourceRankingsDao;
  });

  tearDown(() async {
    await db.close();
  });

  test('appendSource adds at rank 0 when table is empty', () async {
    await dao.appendSource('a');
    expect(await dao.watchRankedSourceIds().first, ['a']);
  });

  test('appendSource increments rank for successive sources', () async {
    await dao.appendSource('a');
    await dao.appendSource('b');
    await dao.appendSource('c');
    expect(await dao.watchRankedSourceIds().first, ['a', 'b', 'c']);
  });

  test('appendSource assigns a non-null cloudId', () async {
    await dao.appendSource('a');
    final row = await dao.getBySourceId('a');
    expect(row, isNotNull);
    expect(row!.cloudId, isNotNull);
    expect(row.cloudId!.length, greaterThan(10));
  });

  test('appendSource is idempotent', () async {
    await dao.appendSource('a');
    await dao.appendSource('a'); // second call — no-op
    expect(await dao.watchRankedSourceIds().first, ['a']);
    final rows = await dao.getAll();
    expect(rows.length, 1);
  });

  test('setRanks reorders existing sources', () async {
    await dao.appendSource('a');
    await dao.appendSource('b');
    await dao.appendSource('c');
    await dao.setRanks(['c', 'a', 'b']);
    expect(await dao.watchRankedSourceIds().first, ['c', 'a', 'b']);
  });

  test('setRanks updates modifiedAt', () async {
    await dao.appendSource('a');
    final before = DateTime.now();
    await dao.setRanks(['a']);
    final row = await dao.getBySourceId('a');
    expect(row!.modifiedAt, isNotNull);
    expect(
      row.modifiedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('setRanks is idempotent with the same order', () async {
    await dao.appendSource('a');
    await dao.appendSource('b');
    await dao.setRanks(['a', 'b']);
    await dao.setRanks(['a', 'b']); // no crash
    expect(await dao.watchRankedSourceIds().first, ['a', 'b']);
  });

  test('removeSource deletes the row', () async {
    await dao.appendSource('a');
    await dao.appendSource('b');
    await dao.removeSource('a');
    expect(await dao.watchRankedSourceIds().first, ['b']);
  });

  test('removeSource on unknown id is a no-op', () async {
    await dao.appendSource('a');
    await dao.removeSource('missing'); // must not throw
    expect(await dao.watchRankedSourceIds().first, ['a']);
  });

  test('upsertFromRemote inserts a new record', () async {
    await dao.upsertFromRemote(
      sourceId: 'x',
      cloudId: 'cloud-1',
      rank: 5,
      modifiedAt: DateTime(2025),
    );
    final row = await dao.getBySourceId('x');
    expect(row, isNotNull);
    expect(row!.rank, 5);
    expect(row.cloudId, 'cloud-1');
  });

  test('upsertFromRemote updates rank when remote is newer', () async {
    await dao.appendSource('x');
    final old = await dao.getBySourceId('x');

    await dao.upsertFromRemote(
      sourceId: 'x',
      cloudId: old!.cloudId!,
      rank: 99,
      modifiedAt: DateTime.now().add(const Duration(hours: 1)),
    );
    final updated = await dao.getBySourceId('x');
    expect(updated!.rank, 99);
  });

  test('upsertFromRemote ignores remote when local is newer', () async {
    await dao.appendSource('x');
    final existing = await dao.getBySourceId('x');
    final originalRank = existing!.rank;

    await dao.upsertFromRemote(
      sourceId: 'x',
      cloudId: existing.cloudId!,
      rank: 99,
      modifiedAt: DateTime(2000), // older than local
    );
    final unchanged = await dao.getBySourceId('x');
    expect(unchanged!.rank, originalRank);
  });

  test(
    'upsertFromRemote adopts cloudId by natural key when no cloudId match',
    () async {
      await dao.appendSource('x');
      await dao.upsertFromRemote(
        sourceId: 'x',
        cloudId: 'new-cloud-id',
        rank: 7,
        modifiedAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final row = await dao.getBySourceId('x');
      expect(row!.cloudId, 'new-cloud-id');
      expect(row.rank, 7);
    },
  );

  test('deleteByCloudId removes the row', () async {
    await dao.appendSource('x');
    final row = await dao.getBySourceId('x');
    await dao.deleteByCloudId(row!.cloudId!);
    expect(await dao.getBySourceId('x'), isNull);
  });
}
