import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

enum SyncPhase {
  /// Signed in and ready; not currently syncing.
  idle,

  /// A sync is in flight.
  syncing,

  /// The most recent sync completed without error.
  success,

  /// The sync ran but some records couldn't upload; [SyncState.failedCount]
  /// holds how many and [SyncState.detail] summarizes it.
  partial,

  /// The most recent sync failed; [SyncState.detail] explains why.
  error,

  /// iCloud is not signed in / unavailable on this device.
  unavailable,
}

class SyncState {
  final SyncPhase phase;

  /// Human-readable error or info detail (shown on [SyncPhase.error] /
  /// [SyncPhase.partial]).
  final String? detail;

  /// When the last sync that reached the server completed, if ever.
  final DateTime? lastSyncedAt;

  /// Records that terminally failed to upload on the last sync.
  final int failedCount;

  /// Sample of per-record failure reasons from the last sync (for the tile's
  /// "details" affordance). Empty unless [phase] is [SyncPhase.partial].
  final List<String> failures;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.detail,
    this.lastSyncedAt,
    this.failedCount = 0,
    this.failures = const [],
  });

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncState copyWith({
    SyncPhase? phase,
    String? detail,
    bool clearDetail = false,
    DateTime? lastSyncedAt,
    int? failedCount,
    List<String>? failures,
  }) => SyncState(
    phase: phase ?? this.phase,
    detail: clearDetail ? null : (detail ?? this.detail),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failedCount: failedCount ?? this.failedCount,
    failures: failures ?? this.failures,
  );
}

/// Single source of truth for iCloud sync status, surfaced in the UI.
///
/// Brackets a manual sync with `syncing -> success | error` so the state is
/// always observable, rather than relying on a transient event stream that
/// never carried errors.
class SyncNotifier extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    return SyncState(phase: await _phaseFromAvailability());
  }

  /// [fullPush] re-stages every local row (the manual "Sync Now" safety net);
  /// otherwise only incrementally-staged changes are flushed.
  Future<void> syncNow({bool fullPush = false}) async {
    final current = state.value ?? const SyncState();
    if (current.isSyncing) return; // guard against double-trigger

    final sync = ref.read(cloudKitSyncServiceProvider);
    bool available;
    try {
      available = await sync.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) {
      state = AsyncData(
        current.copyWith(phase: SyncPhase.unavailable, clearDetail: true),
      );
      return;
    }

    state = AsyncData(
      current.copyWith(phase: SyncPhase.syncing, clearDetail: true),
    );
    try {
      final result = await ref
          .read(syncOutboundProvider)
          .syncNow(fullPush: fullPush);
      final now = DateTime.now();
      if (result.hasFailures) {
        state = AsyncData(_partialState(current, result, now));
      } else {
        state = AsyncData(
          current.copyWith(
            phase: SyncPhase.success,
            clearDetail: true,
            failedCount: 0,
            failures: const [],
            lastSyncedAt: now,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        current.copyWith(phase: SyncPhase.error, detail: _humanize(e)),
      );
    }
  }

  /// Folds the outcome of a background push (the debounced auto-push or a
  /// push-triggered pull from [SyncStager]) into the visible status, so a
  /// silent auto-push's failures surface on the tile instead of waiting for the
  /// next manual sync. Successes only refresh the timestamp / clear a prior
  /// problem — they never flip the phase to `success` from idle, so they don't
  /// trigger the launch-style "Sync complete" snackbar while the user reads.
  void reportBackgroundResult(SendResult result) {
    final current = state.value;
    if (current == null || current.isSyncing)
      return; // manual sync is authoritative
    final now = DateTime.now();
    if (result.hasFailures) {
      state = AsyncData(_partialState(current, result, now));
      return;
    }
    // Success: clear a previously-reported problem, else just bump the time.
    final recovered =
        current.phase == SyncPhase.partial || current.phase == SyncPhase.error;
    state = AsyncData(
      current.copyWith(
        phase: recovered ? SyncPhase.success : current.phase,
        clearDetail: recovered,
        failedCount: 0,
        failures: const [],
        lastSyncedAt: now,
      ),
    );
  }

  static SyncState _partialState(
    SyncState current,
    SendResult result,
    DateTime at,
  ) {
    final n = result.failedCount;
    return current.copyWith(
      phase: SyncPhase.partial,
      detail: "$n item${n == 1 ? '' : 's'} couldn't upload",
      failedCount: n,
      failures: result.failures,
      lastSyncedAt: at,
    );
  }

  Future<SyncPhase> _phaseFromAvailability() async {
    try {
      final available = await ref
          .read(cloudKitSyncServiceProvider)
          .isAvailable();
      return available ? SyncPhase.idle : SyncPhase.unavailable;
    } catch (_) {
      // Platform channel unavailable (non-Apple platform, etc.).
      return SyncPhase.unavailable;
    }
  }

  String _humanize(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);
