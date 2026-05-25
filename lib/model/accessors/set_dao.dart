import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/util/uuid.dart';

part 'set_dao.g.dart';

@DriftAccessor(tables: [TuneSets])
class SetDao extends DatabaseAccessor<AppDatabase> with _$SetDaoMixin {
  SetDao(super.db);

  Future<List<TuneSet>> getAll() => select(tuneSets).get();
  Future<TuneSet?> getSet(int id) =>
      (select(tuneSets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSet(TuneSetsCompanion set) async {
    final cloudId = set.cloudId.present && set.cloudId.value != null
        ? set.cloudId.value!
        : generateUuid();
    final id = await into(tuneSets).insert(set.copyWith(cloudId: Value(cloudId)));
    attachedDatabase.notifyRowChanged('TuneSet', cloudId, deleted: false);
    return id;
  }

  Future<TuneSet?> getByCloudId(String cloudId) =>
      (select(tuneSets)..where((t) => t.cloudId.equals(cloudId)))
          .getSingleOrNull();

  // Dedupe lookup: a set created independently of CloudKit adopts the incoming
  // remote record instead of duplicating it.
  Future<TuneSet?> getByName(String name) =>
      (select(tuneSets)
            ..where((t) => t.name.equals(name))
            ..limit(1))
          .getSingleOrNull();

  Stream<List<TuneSet>> watchAllSets() => select(tuneSets).watch();

  Stream<TuneSet?> watchSet(int id) =>
      (select(tuneSets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> updateSet(TuneSetsCompanion updated) async {
    final count =
        await (update(tuneSets)..where((t) => t.id.equals(updated.id.value)))
            .write(updated);
    final row = await getSet(updated.id.value);
    attachedDatabase.notifyRowChanged('TuneSet', row?.cloudId, deleted: false);
    return count;
  }

  Future<int> deleteSet(int id) async {
    final row = await getSet(id);
    final count = await (delete(tuneSets)..where((t) => t.id.equals(id))).go();
    attachedDatabase.notifyRowChanged('TuneSet', row?.cloudId, deleted: true);
    return count;
  }
}
