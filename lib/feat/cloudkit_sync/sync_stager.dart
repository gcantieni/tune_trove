import 'dart:async';

import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/model/database.dart';

/// Stages local mutations for CloudKit as they happen and pushes them on a
/// short debounce, so edits sync automatically without a manual "Sync Now".
///
/// It registers [AppDatabase.onRowChanged]; the engine persists the staged
/// pending set, so a change survives an app restart even if it wasn't sent.
class SyncStager {
  final AppDatabase _db;
  final CloudKitSyncService _sync;
  final SyncOutboundService _outbound;

  Timer? _debounce;
  Timer? _pullDebounce;
  StreamSubscription<void>? _remoteSub;
  bool _started = false;

  SyncStager(this._db, this._sync, this._outbound);

  void start() {
    if (_started) return;
    _started = true;
    _db.onRowChanged = _onRowChanged;
    // A silent push from another device → pull the latest (no snackbar).
    _remoteSub = _sync.remoteChanges.listen((_) => _onRemoteChange());
  }

  void dispose() {
    _debounce?.cancel();
    _pullDebounce?.cancel();
    _remoteSub?.cancel();
    _db.onRowChanged = null;
    _started = false;
  }

  void _onRemoteChange() {
    _pullDebounce?.cancel();
    _pullDebounce = Timer(const Duration(milliseconds: 500), () {
      // Silent: bypasses SyncNotifier so no snackbar pops while the user reads.
      unawaited(_outbound.syncNow().catchError((_) => const SendResult()));
    });
  }

  void _onRowChanged(String recordType, String cloudId, {required bool deleted}) {
    unawaited(_stage(recordType, cloudId, deleted: deleted));
  }

  Future<void> _stage(
    String recordType,
    String cloudId, {
    required bool deleted,
  }) async {
    try {
      await _sync.initialize();
      if (deleted) {
        await _sync.stageDeletions([
          {'recordType': recordType, 'cloudId': cloudId},
        ]);
      } else {
        final record = await _outbound.serializeByCloudId(recordType, cloudId);
        if (record == null) return;
        await _sync.stageRecords([record]);
      }
      _scheduleSend();
    } catch (_) {
      // Best-effort: a row that fails to stage is recovered by the next
      // full-push sync (manual "Sync Now").
    }
  }

  void _scheduleSend() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      // Quiet background push; failures surface on the next manual sync.
      unawaited(_sync.sendChanges().catchError((_) => const SendResult()));
    });
  }
}
