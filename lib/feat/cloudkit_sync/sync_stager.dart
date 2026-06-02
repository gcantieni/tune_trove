import 'dart:async';

import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/model/database.dart';

/// Stages local mutations for CloudKit as they happen and pushes them on a
/// short debounce, so edits sync automatically without a manual "Sync Now".
///
/// It registers [AppDatabase.onRowChanged]; the engine persists the staged
/// pending set, so a change survives an app restart even if it wasn't sent.
///
/// A low-frequency [sweepInterval] full-push runs in the background as a
/// self-heal: if a mutation path is ever added without an [AppDatabase
/// .onRowChanged] call, the row is re-staged on the next sweep instead of
/// silently never syncing until the user taps "Sync Now".
class SyncStager {
  final AppDatabase _db;
  final CloudKitSyncService _sync;
  final SyncOutboundService _outbound;

  /// Invoked with the outcome of every background push (the debounced
  /// auto-push, a push-triggered pull, and the periodic sweep) so the UI can
  /// surface failures that would otherwise stay hidden until a manual sync.
  final void Function(SendResult result)? onResult;

  /// How often the self-heal full-push sweep runs while the app is alive.
  final Duration sweepInterval;

  Timer? _debounce;
  Timer? _pullDebounce;
  Timer? _sweep;
  StreamSubscription<void>? _remoteSub;
  bool _started = false;

  SyncStager(
    this._db,
    this._sync,
    this._outbound, {
    this.onResult,
    this.sweepInterval = const Duration(minutes: 30),
  });

  void start() {
    if (_started) return;
    _started = true;
    _db.onRowChanged = _onRowChanged;
    // A silent push from another device → pull the latest (no snackbar).
    _remoteSub = _sync.remoteChanges.listen((_) => _onRemoteChange());
    // Periodic self-heal: re-stage everything so a row a hook missed still
    // converges without waiting for a manual full-push.
    _sweep = Timer.periodic(sweepInterval, (_) => _runSweep());
  }

  void dispose() {
    _debounce?.cancel();
    _pullDebounce?.cancel();
    _sweep?.cancel();
    _remoteSub?.cancel();
    _db.onRowChanged = null;
    _started = false;
  }

  void _onRemoteChange() {
    _pullDebounce?.cancel();
    _pullDebounce = Timer(const Duration(milliseconds: 500), () {
      // Push-triggered pull: bypasses the manual-sync snackbar, but failures
      // are still reported to [onResult] so the tile reflects them.
      unawaited(_report(_outbound.syncNow()));
    });
  }

  void _runSweep() {
    // Force-stage every row, catching any mutation a hook may have missed.
    unawaited(_report(_outbound.syncNow(fullPush: true)));
  }

  void _onRowChanged(
    String recordType,
    String cloudId, {
    required bool deleted,
  }) {
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
      // Best-effort: a row that fails to stage is recovered by the periodic
      // sweep or the next full-push sync (manual "Sync Now").
    }
  }

  void _scheduleSend() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      // Quiet background push; failures are reported to [onResult] so they
      // surface on the tile rather than waiting for the next manual sync.
      unawaited(_report(_sync.sendChanges()));
    });
  }

  /// Awaits a background push and forwards its outcome to [onResult], swallowing
  /// errors (a thrown send is treated as a no-op result, not a crash).
  Future<void> _report(Future<SendResult> push) async {
    SendResult result;
    try {
      result = await push;
    } catch (_) {
      return;
    }
    onResult?.call(result);
  }
}
