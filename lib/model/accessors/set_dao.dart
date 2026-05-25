import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/util/uuid.dart';

part 'set_dao.g.dart';

@DriftAccessor(tables: [TuneSets])
class SetDao extends DatabaseAccessor<AppDatabase> with _$SetDaoMixin {
  SetDao(super.db);

  Future<int> insertSet(TuneSetsCompanion set) {
    final companion =
        set.cloudId.present ? set : set.copyWith(cloudId: Value(generateUuid()));
    return into(tuneSets).insert(companion);
  }

  Future<TuneSet?> getByCloudId(String cloudId) =>
      (select(tuneSets)..where((t) => t.cloudId.equals(cloudId)))
          .getSingleOrNull();

  Stream<List<TuneSet>> watchAllSets() => select(tuneSets).watch();

  Stream<TuneSet?> watchSet(int id) =>
      (select(tuneSets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> updateSet(TuneSetsCompanion updated) => (update(
    tuneSets,
  )..where((t) => t.id.equals(updated.id.value))).write(updated);

  Future<int> deleteSet(int id) =>
      (delete(tuneSets)..where((t) => t.id.equals(id))).go();
}
