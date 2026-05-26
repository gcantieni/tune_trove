import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';

/// Wraps a scrollable [child] with pull-to-refresh that triggers an iCloud
/// sync (fetch latest from other devices, then push any local changes).
///
/// Status feedback ("Syncing from iCloud" / "Sync complete") is shown by the
/// app-level listener on [syncProvider], so this widget only drives the sync.
///
/// [child] should be an always-scrollable view (e.g. a `ListView` with
/// [AlwaysScrollableScrollPhysics]) so the gesture works even when the list is
/// short or empty.
class SyncRefreshIndicator extends ConsumerWidget {
  const SyncRefreshIndicator({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(syncProvider.notifier).syncNow(),
      child: child,
    );
  }
}
