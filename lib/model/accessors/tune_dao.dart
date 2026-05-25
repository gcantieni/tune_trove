import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/util/uuid.dart';

part 'tune_dao.g.dart';

@DriftAccessor(tables: [Tunes])
class TuneDao extends DatabaseAccessor<AppDatabase> with _$TuneDaoMixin {
  TuneDao(super.db);

  // create
  Future<int> insertTune(TunesCompanion tune) {
    final companion =
        tune.cloudId.present ? tune : tune.copyWith(cloudId: Value(generateUuid()));
    return into(tunes).insert(companion);
  }

  // read static
  Future<List<Tune>> getAll() => select(tunes).get();
  Future<Tune?> getTune(int id) =>
      (select(tunes)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Tune?> getByCloudId(String cloudId) =>
      (select(tunes)..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  // Dedupe lookups: match a row created independently of CloudKit so an
  // incoming remote record adopts the existing row instead of duplicating it.
  Future<Tune?> getByTsId(int tsId) =>
      (select(tunes)
            ..where((t) => t.tsId.equals(tsId))
            ..limit(1))
          .getSingleOrNull();
  Future<Tune?> getByName(String name) =>
      (select(tunes)
            ..where((t) => t.name.equals(name))
            ..limit(1))
          .getSingleOrNull();

  // read reactive
  Stream<List<Tune>> watchAllTunes() => select(tunes).watch();
  Stream<Tune?> watchTune(int id) =>
      (select(tunes)..where((t) => t.id.equals(id))).watchSingleOrNull();

  // update
  Future<int> updateTune(TunesCompanion updatedTune) => (update(
    tunes,
  )..where((t) => t.id.equals(updatedTune.id.value))).write(updatedTune);

  // delete
  Future deleteTune(int id) =>
      (delete(tunes)..where((t) => t.id.equals(id))).go();
}
