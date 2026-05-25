import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';
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
    final statusAsync = ref.watch(syncStatusProvider);

    final (icon, subtitle) = switch (statusAsync) {
      AsyncLoading() => (Icons.cloud_outlined, 'Connecting…'),
      AsyncError(:final error) => (Icons.cloud_off, error.toString()),
      AsyncData(:final value) => switch (value.status) {
          'syncing' => (Icons.cloud_sync, 'Syncing…'),
          'error' => (Icons.cloud_off, value.message ?? 'Sync error'),
          _ => (Icons.cloud_done, 'iCloud sync on'),
        },
    };

    return ListTile(
      leading: Icon(icon),
      title: const Text('iCloud Sync'),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.sync),
        tooltip: 'Sync now',
        onPressed: () async {
          final sync = ref.read(cloudKitSyncServiceProvider);
          final outbound = ref.read(syncOutboundProvider);
          try {
            final available = await sync.isAvailable();
            if (!available) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'iCloud is not available. Sign in to iCloud in Settings.',
                    ),
                  ),
                );
              }
              return;
            }
            // Pull first (ensures zone exists, merges any remote changes),
            // then push local records to CloudKit.
            await sync.startSync();
            await outbound.pushAll();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sync error: $e')),
              );
            }
          }
        },
      ),
    );
  }
}
