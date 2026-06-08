import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/backup/backup_providers.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';
import 'package:tune_trove/feat/settings/settings_providers.dart';
import 'package:tune_trove/model/database_provider.dart';

class SettingsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Surface backup export/import outcomes as a snackbar.
    ref.listen<AsyncValue<BackupState>>(backupProvider, (_, next) {
      final s = next.value;
      if (s == null) return;
      if (s.phase == BackupPhase.success || s.phase == BackupPhase.error) {
        final msg =
            s.message ??
            (s.phase == BackupPhase.success ? 'Done' : 'Something went wrong');
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SyncStatusTile(),
          const Divider(height: 1),
          _DefaultPageTile(),
          const Divider(height: 1),
          _InvertNotationTile(),
          const Divider(height: 1),
          _ImportDataTile(),
          _ExportDataTile(),
          const SizedBox(height: 24),
          _BuildInfoFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Exports the whole library (tunes, recordings, sets, sources) plus the audio
/// files into a ZIP and hands it to the system share sheet.
class _ExportDataTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupProvider).value ?? const BackupState();
    final exporting = state.phase == BackupPhase.exporting;
    return ListTile(
      leading: exporting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share),
      title: const Text('Export backup'),
      subtitle: const Text('Save a ZIP of your library and audio files'),
      onTap: state.isBusy
          ? null
          : () => ref
                .read(backupProvider.notifier)
                .exportBackup(sharePositionOrigin: _originOf(context)),
    );
  }

  /// The tile's global rect, used to anchor the iOS share popover (iOS throws
  /// without a non-zero origin).
  Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Imports a previously-exported backup ZIP, merging it into the library.
/// Non-destructive: existing items are kept and duplicates are skipped.
class _ImportDataTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupProvider).value ?? const BackupState();
    final importing = state.phase == BackupPhase.importing;
    return ListTile(
      leading: importing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.unarchive_outlined),
      title: const Text('Import backup'),
      subtitle: const Text('Merge a backup ZIP into your library'),
      onTap: state.isBusy ? null : () => _confirmAndImport(context, ref),
    );
  }

  Future<void> _confirmAndImport(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'Pick a backup ZIP to merge into your library. Existing items are '
          'kept and matching items are not duplicated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(backupProvider.notifier).importBackup();
    }
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Build info copied')));
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

/// Chooses which tab the app opens to on launch. Device-local; takes effect on
/// the next launch (the running session isn't renavigated).
class _DefaultPageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(defaultPageProvider);
    return ListTile(
      leading: const Icon(Icons.home_outlined),
      title: const Text('Default page'),
      subtitle: const Text('The tab the app opens to on launch'),
      trailing: DropdownButton<String>(
        value: current,
        underline: const SizedBox.shrink(),
        onChanged: (route) {
          if (route == null) return;
          ref.read(defaultPageProvider.notifier).set(route);
        },
        items: [
          for (final entry in kDefaultPageRoutes.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
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
