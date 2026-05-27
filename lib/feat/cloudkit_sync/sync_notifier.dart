import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';

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

  const SyncState({
    this.phase = SyncPhase.idle,
    this.detail,
    this.lastSyncedAt,
    this.failedCount = 0,
  });

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncState copyWith({
    SyncPhase? phase,
    String? detail,
    bool clearDetail = false,
    DateTime? lastSyncedAt,
    int? failedCount,
  }) => SyncState(
    phase: phase ?? this.phase,
    detail: clearDetail ? null : (detail ?? this.detail),
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    failedCount: failedCount ?? this.failedCount,
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
        final n = result.failedCount;
        state = AsyncData(
          current.copyWith(
            phase: SyncPhase.partial,
            detail: "$n item${n == 1 ? '' : 's'} couldn't upload",
            failedCount: n,
            lastSyncedAt: now,
          ),
        );
      } else {
        state = AsyncData(
          current.copyWith(
            phase: SyncPhase.success,
            clearDetail: true,
            failedCount: 0,
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
