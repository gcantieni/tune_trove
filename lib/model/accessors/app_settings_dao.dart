import 'package:drift/drift.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/app_settings.dart';
import 'package:tune_trove/util/uuid.dart';

part 'app_settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  // read -----------------------------------------------------------------------

  /// Reactive value for [key]. Emits `null` when the setting has never been
  /// written, so callers can apply their own default.
  Stream<String?> watchValue(String key) =>
      (select(appSettings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<AppSetting?> getByKey(String key) =>
      (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();

  Future<AppSetting?> getByCloudId(String cloudId) => (select(
    appSettings,
  )..where((t) => t.cloudId.equals(cloudId))).getSingleOrNull();

  Future<List<AppSetting>> getAll() => select(appSettings).get();

  // local mutations ------------------------------------------------------------

  /// Upserts [key] to [value]. Assigns a stable [cloudId] on first write and
  /// bumps [modifiedAt], then notifies the sync layer so the change is staged
  /// for upload.
  Future<void> setValue(String key, String value) async {
    final existing = await getByKey(key);
    final cloudId = existing?.cloudId ?? generateUuid();
    final now = DateTime.now();
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        value: value,
        cloudId: Value(cloudId),
        modifiedAt: Value(now),
      ),
    );
    attachedDatabase.notifyRowChanged('AppSetting', cloudId, deleted: false);
  }

  // inbound reconciliation (CloudKit) ------------------------------------------

  Future<void> upsertFromRemote({
    required String key,
    required String cloudId,
    required String value,
    DateTime? modifiedAt,
  }) async {
    var existing = await getByCloudId(cloudId);
    existing ??= await getByKey(key);

    if (existing != null) {
      final row = existing; // promote to non-nullable for use inside closures
      final localModified = row.modifiedAt;
      final remoteNewer =
          modifiedAt != null &&
          (localModified == null || modifiedAt.isAfter(localModified));
      if (!remoteNewer && row.cloudId == cloudId) return;
      if (remoteNewer) {
        await (update(appSettings)..where((t) => t.key.equals(row.key))).write(
          AppSettingsCompanion(
            value: Value(value),
            cloudId: Value(cloudId),
            modifiedAt: Value(modifiedAt),
          ),
        );
      } else {
        await (update(appSettings)..where((t) => t.key.equals(row.key))).write(
          AppSettingsCompanion(cloudId: Value(cloudId)),
        );
      }
    } else {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(
          key: key,
          value: value,
          cloudId: Value(cloudId),
          modifiedAt: Value(modifiedAt),
        ),
      );
    }
  }

  Future<void> deleteByCloudId(String cloudId) =>
      (delete(appSettings)..where((t) => t.cloudId.equals(cloudId))).go();
}
