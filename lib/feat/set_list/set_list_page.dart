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
          child: sets.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.width * 0.25,
                  ),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text('No sets yet — tap + to create one.'),
                      ),
                    ),
                  ],
                )
              : ReorderableListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).size.width * 0.25,
                  ),
                  itemCount: sets.length,
                  itemBuilder: (context, index) => _SetCard(
                    key: ValueKey(sets[index].id),
                    tuneSet: sets[index],
                    index: index,
                  ),
                  onReorderItem: (oldIndex, newIndex) {
                    ref
                        .read(databaseProvider)
                        .setDao
                        .reorderSet(oldIndex, newIndex);
                  },
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
  const _SetCard({required this.tuneSet, required this.index, super.key});

  final TuneSet tuneSet;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tunesAsync = ref.watch(visibleSetTunesProvider(tuneSet.id));
    final count = tunesAsync.value?.length;
    final subtitle = count == null
        ? null
        : count == 1
        ? '1 tune'
        : '$count tunes';

    return Dismissible(
      key: ValueKey(tuneSet.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(databaseProvider).setDao.deleteSet(tuneSet.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        child: ListTile(
          title: Text(tuneSet.name),
          subtitle: subtitle != null ? Text(subtitle) : null,
          // Drag handle — immediate drag, no long-press needed.
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          onTap: () => context.push('/set_list/${tuneSet.id}'),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete set'),
        content: Text('Delete "${tuneSet.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
