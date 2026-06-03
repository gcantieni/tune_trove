import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';
import 'package:tune_trove/feat/settings/settings_providers.dart';
import 'package:tune_trove/model/database_provider.dart';
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
          const Divider(height: 1),
          _InvertNotationTile(),
          const SizedBox(height: 24),
          _BuildInfoFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Small dimmed build identifier at the bottom of Settings, to help pin down
/// exactly which build a bug report came from. Tap to copy.
class _BuildInfoFooter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(buildInfoProvider).value;
    if (info == null) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.outline,
    );
    return Center(
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: info));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Build info copied')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(info, style: style),
        ),
      ),
    );
  }
}

/// Toggles whether ABC sheet music is inverted (white-on-black) to match the
/// theme in dark mode. Has no visible effect in light mode.
class _InvertNotationTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invert = ref.watch(invertNotationInDarkModeProvider).value ?? true;
    return SwitchListTile(
      secondary: const Icon(Icons.music_note),
      title: const Text('Invert sheet music in dark mode'),
      subtitle: const Text(
        'Render notation white-on-black to match the dark theme',
      ),
      value: invert,
      onChanged: (value) => ref
          .read(databaseProvider)
          .appSettingsDao
          .setValue(kInvertNotationInDarkMode, value.toString()),
    );
  }
}

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(syncProvider).value ?? const SyncState();
    final syncing = state.isSyncing;
    final statusColor = switch (state.phase) {
      SyncPhase.error => scheme.error,
      SyncPhase.partial => Colors.orange.shade800,
      _ => null,
    };

    final leading = syncing
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(_iconFor(state.phase), color: statusColor);

    final hasDetails = state.failures.isNotEmpty;

    return ListTile(
      isThreeLine: statusColor != null,
      leading: leading,
      title: const Text('iCloud Sync'),
      subtitle: Text(
        _subtitleFor(state, syncing, hasDetails),
        style: statusColor != null ? TextStyle(color: statusColor) : null,
      ),
      // When some records couldn't upload, tap to read why.
      onTap: hasDetails ? () => _showFailureDetails(context, state) : null,
      trailing: IconButton(
        icon: const Icon(Icons.sync),
        tooltip: 'Sync now',
        onPressed: syncing
            ? null
            : () => ref.read(syncProvider.notifier).syncNow(fullPush: true),
      ),
    );
  }

  void _showFailureDetails(BuildContext context, SyncState state) {
    final n = state.failedCount;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$n item${n == 1 ? '' : 's'} couldn't upload"),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text(
                'These records will retry on the next sync. If the problem '
                'persists, tap Sync now.',
              ),
              const SizedBox(height: 12),
              for (final f in state.failures)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $f', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(SyncPhase phase) => switch (phase) {
    SyncPhase.syncing => Icons.cloud_sync,
    SyncPhase.success => Icons.cloud_done,
    SyncPhase.partial => Icons.sync_problem,
    SyncPhase.error => Icons.cloud_off,
    SyncPhase.unavailable => Icons.cloud_off,
    SyncPhase.idle => Icons.cloud_outlined,
  };

  String _subtitleFor(SyncState state, bool syncing, bool hasDetails) {
    if (syncing) return 'Syncing…';
    switch (state.phase) {
      case SyncPhase.unavailable:
        return 'Sign in to iCloud to enable sync';
      case SyncPhase.error:
        return state.detail ?? 'Sync failed';
      case SyncPhase.partial:
        final last = state.lastSyncedAt;
        var summary = state.detail ?? 'Some items could not upload';
        if (last != null) summary = '$summary · synced ${_relative(last)}';
        return hasDetails ? '$summary · tap for details' : summary;
      case SyncPhase.idle:
      case SyncPhase.success:
      case SyncPhase.syncing:
        final last = state.lastSyncedAt;
        return last == null
            ? 'Not synced yet'
            : 'Last synced ${_relative(last)}';
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
