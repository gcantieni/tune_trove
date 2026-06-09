import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/tune_list/tune_filter_bar.dart';
import 'package:tune_trove/feat/tune_list/tune_filters.dart';
import 'package:tune_trove/feat/tune_list/tune_list_item.dart';
import 'package:tune_trove/feat/tune_list/tune_type_labels.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';
import 'package:tune_trove/shared_widgets/tune_picker_dialog.dart';

class TuneListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Tunes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TuneFilterBar(),
            Expanded(
              child: SyncRefreshIndicator(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    TuneListWidget(),
                    SizedBox(height: MediaQuery.of(context).size.width * 0.25),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add tune',
        onPressed: () => _showAddTuneDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTuneDialog(BuildContext context, WidgetRef ref) {
    final dao = ref.read(databaseProvider).tuneDao;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TunePickerDialog(
        title: 'Add tune',
        onLibraryTune: (tune) {
          // Already in the library — jump to its detail page.
          context.push('/tune_list/${tune.id}');
        },
        onRemoteTune: (companion) async {
          // Insert the chosen setting, then open its detail page (mirrors the
          // library-tune path, which also jumps to detail).
          final id = await dao.insertTune(
            companion.copyWith(createdAt: drift.Value(DateTime.now())),
          );
          if (context.mounted) context.push('/tune_list/$id');
        },
        onCreateNew: (name) {
          dao.insertTune(
            TunesCompanion.insert(name: name, createdAt: DateTime.now()),
          );
        },
      ),
    );
  }
}

class TuneListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fontSize = 19.0;
    final filters = ref.watch(tuneFiltersProvider);
    final tunesAsync = ref.watch(filteredTunesProvider);

    return tunesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
      data: (tunes) {
        if (tunes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                filters.isActive
                    ? 'No tunes match these filters.'
                    : 'No tunes saved',
                style: const TextStyle(fontSize: fontSize),
              ),
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: filters.sort == TuneSort.grouped
              ? _groupedChildren(tunes)
              : [for (final t in tunes) TuneListItem(tune: t)],
        );
      },
    );
  }

  /// Builds the tune list interleaved with two-tier section headers: a large
  /// genre header ("Scottish") and, beneath it, a fully-qualified type
  /// sub-header ("Scottish Jigs"). Assumes [tunes] is already ordered
  /// genre → type → name (see [TuneSort.grouped] in `tune_filters.dart`).
  List<Widget> _groupedChildren(List<Tune> tunes) {
    final children = <Widget>[];
    String? curGenre;
    String? curType;
    for (final t in tunes) {
      final genre = sectionGenreLabel(t.genre);
      if (genre != curGenre) {
        children.add(_GenreHeader(genre));
        curGenre = genre;
        curType = null;
      }
      final typePlural = t.type == null ? null : tuneTypePlural(t.type!);
      if (typePlural != curType) {
        children.add(_TypeHeader(genre: genre, typePlural: typePlural));
        curType = typePlural;
      }
      children.add(TuneListItem(tune: t));
    }
    return children;
  }
}

/// Large genre section marker for the grouped tune list (e.g. "Scottish").
class _GenreHeader extends StatelessWidget {
  final String genre;
  const _GenreHeader(this.genre);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 2),
      child: Text(
        genre,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Subtle, fully-qualified type sub-header for the grouped tune list (e.g.
/// "Scottish Jigs"). [typePlural] is null for untyped tunes.
class _TypeHeader extends StatelessWidget {
  final String genre;
  final String? typePlural;
  const _TypeHeader({required this.genre, required this.typePlural});

  @override
  Widget build(BuildContext context) {
    final label = typePlural == null ? '$genre · Other' : '$genre $typePlural';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
