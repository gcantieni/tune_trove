import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/set_tune.dart';
import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/util/uuid.dart';

part 'set_tune_dao.g.dart';

typedef SetTuneEntry = ({SetTuneData link, Tune tune});
typedef TuneSetEntry = ({SetTuneData link, TuneSet tuneSet});

@DriftAccessor(tables: [SetTune, TuneSets, Tunes])
class SetTuneDao extends DatabaseAccessor<AppDatabase> with _$SetTuneDaoMixin {
  SetTuneDao(super.db);

  Stream<List<SetTuneEntry>> watchTunesInSet(int setId) {
    final query =
        select(
            setTune,
          ).join([innerJoin(tunes, tunes.id.equalsExp(setTune.tuneId))])
          ..where(setTune.setId.equals(setId))
          ..orderBy([OrderingTerm.asc(setTune.position)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (link: row.readTable(setTune), tune: row.readTable(tunes)),
          )
          .toList(),
    );
  }

  Stream<List<TuneSetEntry>> watchSetsForTune(int tuneId) {
    final query = select(setTune).join([
      innerJoin(tuneSets, tuneSets.id.equalsExp(setTune.setId)),
    ])..where(setTune.tuneId.equals(tuneId));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => (
              link: row.readTable(setTune),
              tuneSet: row.readTable(tuneSets),
            ),
          )
          .toList(),
    );
  }

  Future<List<SetTuneData>> getAll() => select(setTune).get();

  Future<SetTuneData?> getByCloudId(String cloudId) => (select(
    setTune,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<SetTuneData?> getBySetAndTune(int setId, int tuneId) =>
      (select(setTune)
            ..where((t) => t.setId.equals(setId) & t.tuneId.equals(tuneId))
            ..limit(1))
          .getSingleOrNull();

  Future<void> addTuneToSet(
    int setId,
    int tuneId, {
    String? cloudId,
    int? position,
    String? key,
  }) async {
    final linkCloudId = cloudId ?? generateUuid();
    final existing = await (select(
      setTune,
    )..where((t) => t.setId.equals(setId))).get();
    await into(setTune).insert(
      SetTuneCompanion.insert(
        setId: setId,
        tuneId: tuneId,
        position: position ?? existing.length,
        key: Value(key),
        cloudId: Value(linkCloudId),
      ),
    );
    attachedDatabase.notifyRowChanged('SetTune', linkCloudId, deleted: false);
  }

  /// Adopts a remote cloudId onto an existing local link (dedupe merge).
  Future<void> adoptCloudId(int id, String cloudId) =>
      (update(setTune)..where((t) => t.id.equals(id))).write(
        SetTuneCompanion(cloudId: Value(cloudId)),
      );

  Future<void> removeTuneFromSet(int setTuneId) async {
    final row = await (select(
      setTune,
    )..where((t) => t.id.equals(setTuneId))).getSingleOrNull();
    await (delete(setTune)..where((t) => t.id.equals(setTuneId))).go();
    attachedDatabase.notifyRowChanged('SetTune', row?.cloudId, deleted: true);
  }

  Future<void> updateKey(int setTuneId, String? key) async {
    await (update(setTune)..where((t) => t.id.equals(setTuneId))).write(
      SetTuneCompanion(key: Value(key)),
    );
    final row = await (select(
      setTune,
    )..where((t) => t.id.equals(setTuneId))).getSingleOrNull();
    attachedDatabase.notifyRowChanged('SetTune', row?.cloudId, deleted: false);
  }

  Future<void> reorderTune(int setId, int oldIndex, int newIndex) async {
    await transaction(() async {
      final rows =
          await (select(setTune)
                ..where((t) => t.setId.equals(setId))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      final list = List<SetTuneData>.from(rows);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      for (var i = 0; i < list.length; i++) {
        await (update(setTune)..where((t) => t.id.equals(list[i].id))).write(
          SetTuneCompanion(position: Value(i)),
        );
        attachedDatabase.notifyRowChanged(
          'SetTune',
          list[i].cloudId,
          deleted: false,
        );
      }
    });
  }
}
