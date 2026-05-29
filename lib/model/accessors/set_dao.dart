import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/util/uuid.dart';

part 'set_dao.g.dart';

@DriftAccessor(tables: [TuneSets])
class SetDao extends DatabaseAccessor<AppDatabase> with _$SetDaoMixin {
  SetDao(super.db);

  Future<List<TuneSet>> getAll() => (select(
    tuneSets,
  )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
  Future<TuneSet?> getSet(int id) =>
      (select(tuneSets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSet(TuneSetsCompanion set) async {
    final cloudId = set.cloudId.present && set.cloudId.value != null
        ? set.cloudId.value!
        : generateUuid();
    // New sets land at the end of the list unless a position was supplied
    // (e.g. by inbound CloudKit sync, which carries the remote position).
    final position = set.position.present
        ? set.position
        : Value(await tuneSets.count().getSingle());
    final id = await into(
      tuneSets,
    ).insert(set.copyWith(cloudId: Value(cloudId), position: position));
    attachedDatabase.notifyRowChanged('TuneSet', cloudId, deleted: false);
    return id;
  }

  Future<TuneSet?> getByCloudId(String cloudId) => (select(
    tuneSets,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  // Dedupe lookup: a set created independently of CloudKit adopts the incoming
  // remote record instead of duplicating it.
  Future<TuneSet?> getByName(String name) =>
      (select(tuneSets)
            ..where((t) => t.name.equals(name))
            ..limit(1))
          .getSingleOrNull();

  Stream<List<TuneSet>> watchAllSets() => (select(
    tuneSets,
  )..orderBy([(t) => OrderingTerm.asc(t.position)])).watch();

  Stream<TuneSet?> watchSet(int id) =>
      (select(tuneSets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<int> updateSet(TuneSetsCompanion updated) async {
    final count = await (update(
      tuneSets,
    )..where((t) => t.id.equals(updated.id.value))).write(updated);
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

  /// Moves the set at [oldIndex] to [newIndex] (positions in the current
  /// ascending-`position` ordering) and renumbers every set so positions stay
  /// contiguous. Mirrors [SetTuneDao.reorderTune].
  Future<void> reorderSet(int oldIndex, int newIndex) async {
    await transaction(() async {
      final rows = await (select(
        tuneSets,
      )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();

      final list = List<TuneSet>.from(rows);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      for (var i = 0; i < list.length; i++) {
        if (list[i].position == i) continue;
        await (update(tuneSets)..where((t) => t.id.equals(list[i].id))).write(
          TuneSetsCompanion(position: Value(i)),
        );
        attachedDatabase.notifyRowChanged(
          'TuneSet',
          list[i].cloudId,
          deleted: false,
        );
      }
    });
  }
}
