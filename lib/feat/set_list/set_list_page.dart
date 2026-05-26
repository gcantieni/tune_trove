import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/sets_provider.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class SetListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(allSetsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Sets'),
      ),
      body: setsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sets) => SyncRefreshIndicator(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: sets.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('No sets yet — tap + to create one.'),
                      ),
                    ),
                  ]
                : [for (final s in sets) _SetCard(tuneSet: s)],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New set',
        onPressed: () => _createSet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createSet(BuildContext context, WidgetRef ref) async {
    final id = await ref
        .read(databaseProvider)
        .setDao
        .insertSet(
          TuneSetsCompanion.insert(
            name: 'New set',
            createdAt: DateTime.now(),
            modifiedAt: const Value(null),
          ),
        );
    if (context.mounted) context.push('/set_list/$id');
  }
}

class _SetCard extends ConsumerWidget {
  const _SetCard({required this.tuneSet});

  final TuneSet tuneSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunesAsync = ref.watch(visibleSetTunesProvider(tuneSet.id));
    final count = tunesAsync.value?.length;
    final subtitle = count == null
        ? null
        : count == 1
        ? '1 tune'
        : '$count tunes';

    return Card(
      child: ListTile(
        title: Text(tuneSet.name),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/set_list/${tuneSet.id}'),
      ),
    );
  }
}
