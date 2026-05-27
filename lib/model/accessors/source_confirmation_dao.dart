import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/source_confirmations.dart';
import 'package:tune_trove/util/uuid.dart';

part 'source_confirmation_dao.g.dart';

@DriftAccessor(tables: [SourceConfirmations])
class SourceConfirmationDao extends DatabaseAccessor<AppDatabase>
    with _$SourceConfirmationDaoMixin {
  SourceConfirmationDao(super.db);

  // read
  Future<List<SourceConfirmation>> getAll() =>
      select(sourceConfirmations).get();

  /// Reactive set of confirmed source ids. The confirmation state UI watches
  /// this, so a confirmation synced in from another device shows up live.
  Stream<Set<String>> watchConfirmedIds() => select(
    sourceConfirmations,
  ).watch().map((rows) => rows.map((r) => r.sourceId).toSet());

  Future<SourceConfirmation?> getByCloudId(String cloudId) => (select(
    sourceConfirmations,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<SourceConfirmation?> getBySourceId(String sourceId) => (select(
    sourceConfirmations,
  )..where((t) => t.sourceId.equals(sourceId))).getSingleOrNull();

  // local user actions ------------------------------------------------------

  Future<void> confirm(String sourceId, String license) async {
    if (await getBySourceId(sourceId) != null) return; // already confirmed
    final cloudId = generateUuid();
    await into(sourceConfirmations).insert(
      SourceConfirmationsCompanion.insert(
        sourceId: sourceId,
        license: Value(license),
        createdAt: DateTime.now(),
        cloudId: Value(cloudId),
      ),
    );
    attachedDatabase.notifyRowChanged(
      'SourceConfirmation',
      cloudId,
      deleted: false,
    );
  }

  Future<void> revoke(String sourceId) async {
    final existing = await getBySourceId(sourceId);
    if (existing == null) return;
    await (delete(
      sourceConfirmations,
    )..where((t) => t.sourceId.equals(sourceId))).go();
    attachedDatabase.notifyRowChanged(
      'SourceConfirmation',
      existing.cloudId,
      deleted: true,
    );
  }

  // inbound reconciliation ---------------------------------------------------

  Future<void> insertFromRemote({
    required String sourceId,
    required String cloudId,
    String? license,
    required DateTime createdAt,
    DateTime? modifiedAt,
  }) => into(sourceConfirmations).insert(
    SourceConfirmationsCompanion.insert(
      sourceId: sourceId,
      license: Value(license),
      createdAt: createdAt,
      modifiedAt: Value(modifiedAt),
      cloudId: Value(cloudId),
    ),
  );

  Future<void> adoptRemote(
    int id, {
    required String cloudId,
    String? license,
    DateTime? modifiedAt,
  }) => (update(sourceConfirmations)..where((t) => t.id.equals(id))).write(
    SourceConfirmationsCompanion(
      cloudId: Value(cloudId),
      license: Value(license),
      modifiedAt: Value(modifiedAt),
    ),
  );

  Future<void> deleteByCloudId(String cloudId) => (delete(
    sourceConfirmations,
  )..where((t) => t.cloudId.equals(cloudId))).go();
}
