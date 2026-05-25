import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class SettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SyncStatusTile(),
        ],
      ),
    );
  }
}

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(syncProvider).value ?? const SyncState();
    final syncing = state.isSyncing;
    final isError = state.phase == SyncPhase.error;

    final leading = syncing
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_iconFor(state.phase), color: isError ? scheme.error : null);

    return ListTile(
      isThreeLine: isError,
      leading: leading,
      title: const Text('iCloud Sync'),
      subtitle: Text(
        _subtitleFor(state, syncing),
        style: isError ? TextStyle(color: scheme.error) : null,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.sync),
        tooltip: 'Sync now',
        onPressed: syncing ? null : () => ref.read(syncProvider.notifier).syncNow(),
      ),
    );
  }

  IconData _iconFor(SyncPhase phase) => switch (phase) {
    SyncPhase.syncing => Icons.cloud_sync,
    SyncPhase.success => Icons.cloud_done,
    SyncPhase.error => Icons.cloud_off,
    SyncPhase.unavailable => Icons.cloud_off,
    SyncPhase.idle => Icons.cloud_outlined,
  };

  String _subtitleFor(SyncState state, bool syncing) {
    if (syncing) return 'Syncing…';
    switch (state.phase) {
      case SyncPhase.unavailable:
        return 'Sign in to iCloud to enable sync';
      case SyncPhase.error:
        return state.detail ?? 'Sync failed';
      case SyncPhase.idle:
      case SyncPhase.success:
      case SyncPhase.syncing:
        final last = state.lastSyncedAt;
        return last == null ? 'Not synced yet' : 'Last synced ${_relative(last)}';
    }
  }

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final m = t.month.toString().padLeft(2, '0');
    final day = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$day';
  }
}
