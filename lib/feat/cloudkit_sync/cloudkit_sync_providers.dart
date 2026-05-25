import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/platform_cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/model/database_provider.dart';

final cloudKitSyncServiceProvider = Provider<CloudKitSyncService>((ref) {
  final service = PlatformCloudKitSyncService();
  ref.onDispose(service.dispose);
  return service;
});

final syncReconciliationProvider = Provider<SyncReconciliationService>((ref) {
  final db = ref.watch(databaseProvider);
  final sync = ref.watch(cloudKitSyncServiceProvider);
  final service = SyncReconciliationService(db, sync);
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

final syncOutboundProvider = Provider<SyncOutboundService>((ref) {
  final db = ref.watch(databaseProvider);
  final sync = ref.watch(cloudKitSyncServiceProvider);
  return SyncOutboundService(db, sync);
});

final syncStatusProvider = StreamProvider<SyncStatusEvent>((ref) {
  final sync = ref.watch(cloudKitSyncServiceProvider);
  return sync.syncEvents
      .where((e) => e is SyncStatusEvent)
      .cast<SyncStatusEvent>();
});
