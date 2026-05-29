import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/app_settings_dao.dart';
import 'package:tune_trove/model/database.dart';

void main() {
  late AppDatabase db;
  late AppSettingsDao dao;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dao = db.appSettingsDao;
  });

  tearDown(() async {
    await db.close();
  });

  test('watchValue emits null for an unwritten key', () async {
    expect(await dao.watchValue('missing').first, isNull);
  });

  test('setValue inserts a row with a non-null cloudId and modifiedAt', () async {
    await dao.setValue('invertNotationInDarkMode', 'false');
    final row = await dao.getByKey('invertNotationInDarkMode');
    expect(row, isNotNull);
    expect(row!.value, 'false');
    expect(row.cloudId, isNotNull);
    expect(row.cloudId!.length, greaterThan(10));
    expect(row.modifiedAt, isNotNull);
  });

  test('setValue updates in place and keeps the same cloudId', () async {
    await dao.setValue('k', 'true');
    final first = await dao.getByKey('k');
    await dao.setValue('k', 'false');
    final second = await dao.getByKey('k');
    expect(second!.value, 'false');
    expect(second.cloudId, first!.cloudId);
    expect(await dao.getAll(), hasLength(1));
  });

  test('watchValue reflects subsequent writes', () async {
    await dao.setValue('k', 'true');
    expect(await dao.watchValue('k').first, 'true');
    await dao.setValue('k', 'false');
    expect(await dao.watchValue('k').first, 'false');
  });

  test('upsertFromRemote inserts a new record', () async {
    await dao.upsertFromRemote(
      key: 'k',
      cloudId: 'cloud-1',
      value: 'true',
      modifiedAt: DateTime(2025),
    );
    final row = await dao.getByKey('k');
    expect(row!.value, 'true');
    expect(row.cloudId, 'cloud-1');
  });

  test('upsertFromRemote applies a newer remote value', () async {
    await dao.setValue('k', 'true');
    final existing = await dao.getByKey('k');
    await dao.upsertFromRemote(
      key: 'k',
      cloudId: existing!.cloudId!,
      value: 'false',
      modifiedAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect((await dao.getByKey('k'))!.value, 'false');
  });

  test('upsertFromRemote ignores an older remote value', () async {
    await dao.setValue('k', 'true');
    final existing = await dao.getByKey('k');
    await dao.upsertFromRemote(
      key: 'k',
      cloudId: existing!.cloudId!,
      value: 'false',
      modifiedAt: DateTime(2000),
    );
    expect((await dao.getByKey('k'))!.value, 'true');
  });

  test('upsertFromRemote adopts cloudId by natural key (the setting key)', () async {
    await dao.setValue('k', 'true');
    await dao.upsertFromRemote(
      key: 'k',
      cloudId: 'remote-cloud-id',
      value: 'false',
      modifiedAt: DateTime.now().add(const Duration(hours: 1)),
    );
    final row = await dao.getByKey('k');
    expect(row!.cloudId, 'remote-cloud-id');
    expect(row.value, 'false');
    expect(await dao.getAll(), hasLength(1));
  });

  test('deleteByCloudId removes the row', () async {
    await dao.setValue('k', 'true');
    final row = await dao.getByKey('k');
    await dao.deleteByCloudId(row!.cloudId!);
    expect(await dao.getByKey('k'), isNull);
  });
}
