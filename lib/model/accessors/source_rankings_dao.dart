import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/source_rankings.dart';
import 'package:tune_trove/util/uuid.dart';

part 'source_rankings_dao.g.dart';

@DriftAccessor(tables: [SourceRankings])
class SourceRankingsDao extends DatabaseAccessor<AppDatabase>
    with _$SourceRankingsDaoMixin {
  SourceRankingsDao(super.db);

  // read -----------------------------------------------------------------------

  Stream<List<String>> watchRankedSourceIds() =>
      (select(sourceRankings)..orderBy([(t) => OrderingTerm.asc(t.rank)]))
          .watch()
          .map((rows) => rows.map((r) => r.sourceId).toList());

  Future<SourceRanking?> getByCloudId(String cloudId) => (select(
    sourceRankings,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<SourceRanking?> getBySourceId(String sourceId) => (select(
    sourceRankings,
  )..where((t) => t.sourceId.equals(sourceId))).getSingleOrNull();

  Future<List<SourceRanking>> getAll() => select(sourceRankings).get();

  // local mutations ------------------------------------------------------------

  /// Appends [sourceId] to the end of the ranking list. No-op if already present.
  Future<void> appendSource(String sourceId) async {
    if (await getBySourceId(sourceId) != null) return;
    final last =
        await (select(sourceRankings)
              ..orderBy([(t) => OrderingTerm.desc(t.rank)])
              ..limit(1))
            .getSingleOrNull();
    final nextRank = last == null ? 0 : last.rank + 1;
    final cloudId = generateUuid();
    await into(sourceRankings).insert(
      SourceRankingsCompanion.insert(
        sourceId: sourceId,
        rank: nextRank,
        cloudId: Value(cloudId),
        modifiedAt: Value(DateTime.now()),
      ),
    );
    attachedDatabase.notifyRowChanged('SourceRanking', cloudId, deleted: false);
  }

  /// Bulk-updates ranks so [orderedIds[0]] is rank 0, [orderedIds[1]] is rank 1,
  /// etc. IDs not found in the table are silently skipped.
  Future<void> setRanks(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final existing = await getBySourceId(orderedIds[i]);
        if (existing == null) continue;
        if (existing.rank == i) continue; // already correct
        final now = DateTime.now();
        await (update(
          sourceRankings,
        )..where((t) => t.sourceId.equals(orderedIds[i]))).write(
          SourceRankingsCompanion(rank: Value(i), modifiedAt: Value(now)),
        );
        if (existing.cloudId != null) {
          attachedDatabase.notifyRowChanged(
            'SourceRanking',
            existing.cloudId,
            deleted: false,
          );
        }
      }
    });
  }

  /// Removes [sourceId] from the ranking table. No-op if not present.
  Future<void> removeSource(String sourceId) async {
    final existing = await getBySourceId(sourceId);
    if (existing == null) return;
    await (delete(
      sourceRankings,
    )..where((t) => t.sourceId.equals(sourceId))).go();
    attachedDatabase.notifyRowChanged(
      'SourceRanking',
      existing.cloudId,
      deleted: true,
    );
  }

  // inbound reconciliation (CloudKit) ------------------------------------------

  Future<void> upsertFromRemote({
    required String sourceId,
    required String cloudId,
    required int rank,
    DateTime? modifiedAt,
  }) async {
    var existing = await getByCloudId(cloudId);
    existing ??= await getBySourceId(sourceId);

    if (existing != null) {
      final row = existing; // promote to non-nullable for use inside closures
      final localModified = row.modifiedAt;
      final remoteNewer =
          modifiedAt != null &&
          (localModified == null || modifiedAt.isAfter(localModified));
      if (!remoteNewer && row.cloudId == cloudId) return;
      if (remoteNewer) {
        await (update(
          sourceRankings,
        )..where((t) => t.sourceId.equals(row.sourceId))).write(
          SourceRankingsCompanion(
            rank: Value(rank),
            cloudId: Value(cloudId),
            modifiedAt: Value(modifiedAt),
          ),
        );
      } else {
        await (update(sourceRankings)
              ..where((t) => t.sourceId.equals(row.sourceId)))
            .write(SourceRankingsCompanion(cloudId: Value(cloudId)));
      }
    } else {
      await into(sourceRankings).insert(
        SourceRankingsCompanion.insert(
          sourceId: sourceId,
          rank: rank,
          cloudId: Value(cloudId),
          modifiedAt: Value(modifiedAt),
        ),
      );
    }
  }

  Future<void> deleteByCloudId(String cloudId) =>
      (delete(sourceRankings)..where((t) => t.cloudId.equals(cloudId))).go();
}
