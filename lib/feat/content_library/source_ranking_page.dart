import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';

class SourceRankingPage extends ConsumerWidget {
  const SourceRankingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(sourceRankOrderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Order')),
      body: rankAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rankedIds) {
          if (rankedIds.isEmpty) {
            return SyncRefreshIndicator(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No active sources yet. Enable sources in the Content Library.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
          return SyncRefreshIndicator(
            child: ReorderableListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              header: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Drag to set the order sources appear in search results.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              itemCount: rankedIds.length,
              onReorderItem: (oldIndex, newIndex) async {
                final reordered = [...rankedIds];
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                await ref
                    .read(databaseProvider)
                    .sourceRankingsDao
                    .setRanks(reordered);
              },
              itemBuilder: (context, index) {
                final id = rankedIds[index];
                final meta = allContentSources.firstWhere(
                  (m) => m.id == id,
                  orElse: () => ContentSourceMeta(
                    id: id,
                    name: id,
                    genre: '',
                    license: '',
                    attribution: '',
                    confirmationRequired: false,
                  ),
                );
                return _RankTile(key: ValueKey(id), meta: meta);
              },
            ),
          );
        },
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final ContentSourceMeta meta;

  const _RankTile({required super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: key,
      title: Text(meta.name),
      subtitle: Row(
        children: [
          _GenreChip(meta.genre),
          const SizedBox(width: 6),
          Text(meta.license, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String genre;
  const _GenreChip(this.genre);

  @override
  Widget build(BuildContext context) {
    if (genre.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        genre,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
