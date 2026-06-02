import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/platform_cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_stager.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';

final cloudKitSyncServiceProvider = Provider<CloudKitSyncService>((ref) {
  final service = PlatformCloudKitSyncService();
  ref.onDispose(service.dispose);
  return service;
});

final syncReconciliationProvider = Provider<SyncReconciliationService>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncReconciliationService(db);
});

final syncOutboundProvider = Provider<SyncOutboundService>((ref) {
  final db = ref.watch(databaseProvider);
  final sync = ref.watch(cloudKitSyncServiceProvider);
  final reconciliation = ref.watch(syncReconciliationProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncOutboundService(db, sync, reconciliation, prefs);
});

/// Stages local mutations for CloudKit and pushes them on a debounce. Watch
/// this provider once at startup to enable automatic sync-on-change.
final syncStagerProvider = Provider<SyncStager>((ref) {
  final db = ref.watch(databaseProvider);
  final sync = ref.watch(cloudKitSyncServiceProvider);
  final outbound = ref.watch(syncOutboundProvider);
  final stager = SyncStager(
    db,
    sync,
    outbound,
    // Surface background-push failures on the sync tile.
    onResult: (result) =>
        ref.read(syncProvider.notifier).reportBackgroundResult(result),
  );
  stager.start();
  ref.onDispose(stager.dispose);
  return stager;
});
