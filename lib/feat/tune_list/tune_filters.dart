import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/model/tune_genres.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/util/search_normalize.dart';

enum TuneSort {
  grouped,
  newestFirst,
  oldestFirst,
  nameAZ,
  nameZA,
  statusTodoFirst,
  statusMasteredFirst,
}

/// Section label a tune falls under in the [TuneSort.grouped] view: its trimmed
/// genre, or "Other" when it has none. Shared by the comparator and the list UI
/// so grouping and ordering stay in lockstep.
String sectionGenreLabel(String? genre) {
  final g = genre?.trim() ?? '';
  return g.isEmpty ? 'Other' : g;
}

/// Sort rank for a genre section: canonical [kTuneGenres] order first, then any
/// unrecognized free-text genres after (rank == length, broken by label).
int _genreRank(String label) {
  final i = kTuneGenres.indexOf(label);
  return i >= 0 ? i : kTuneGenres.length;
}

/// Sort rank for a tune type within its genre: declaration order in
/// [TuneType.values], with untyped tunes (null) sorted last.
int _typeRank(TuneType? type) =>
    type == null ? TuneType.values.length : type.index;

class TuneFilters {
  final String? genre;
  final TuneType? type;
  final String? key;
  final TuneStatus? status;
  final String nameQuery;
  final TuneSort sort;

  const TuneFilters({
    this.genre,
    this.type,
    this.key,
    this.status,
    this.nameQuery = '',
    this.sort = TuneSort.grouped,
  });

  bool get isActive =>
      (genre != null && genre!.isNotEmpty) ||
      type != null ||
      (key != null && key!.isNotEmpty) ||
      status != null ||
      nameQuery.isNotEmpty ||
      sort != TuneSort.grouped;

  TuneFilters copyWith({
    Object? genre = _sentinel,
    Object? type = _sentinel,
    Object? key = _sentinel,
    Object? status = _sentinel,
    String? nameQuery,
    TuneSort? sort,
  }) {
    return TuneFilters(
      genre: identical(genre, _sentinel) ? this.genre : genre as String?,
      type: identical(type, _sentinel) ? this.type : type as TuneType?,
      key: identical(key, _sentinel) ? this.key : key as String?,
      status: identical(status, _sentinel)
          ? this.status
          : status as TuneStatus?,
      nameQuery: nameQuery ?? this.nameQuery,
      sort: sort ?? this.sort,
    );
  }
}

const _sentinel = Object();

class TuneFiltersNotifier extends Notifier<TuneFilters> {
  @override
  TuneFilters build() => const TuneFilters();

  void setGenre(String? genre) => state = state.copyWith(genre: genre);
  void setType(TuneType? type) => state = state.copyWith(type: type);
  void setKey(String? key) => state = state.copyWith(key: key);
  void setStatus(TuneStatus? status) => state = state.copyWith(status: status);
  void setNameQuery(String query) => state = state.copyWith(nameQuery: query);
  void setSort(TuneSort sort) => state = state.copyWith(sort: sort);
  void clear() => state = const TuneFilters();
}

final tuneFiltersProvider = NotifierProvider<TuneFiltersNotifier, TuneFilters>(
  TuneFiltersNotifier.new,
);

/// Tunes after filters and sort are applied. Filtering is done in Dart
/// because the library is small (hundreds at most) — pushing this into
/// SQL would be premature.
final filteredTunesProvider = Provider.autoDispose<AsyncValue<List<Tune>>>((
  ref,
) {
  final filters = ref.watch(tuneFiltersProvider);
  final activeSourceIds = ref.watch(activeSourceIdsProvider);
  final allAsync = ref.watch(allTunesProvider);
  return allAsync.whenData((all) {
    final query = normalizeForSearch(filters.nameQuery.trim());
    final filtered = all.where((t) {
      if (!isSourceIdVisible(t.source, activeSourceIds)) return false;
      if (filters.genre != null &&
          filters.genre!.isNotEmpty &&
          t.genre != filters.genre) {
        return false;
      }
      if (filters.type != null && t.type != filters.type) return false;
      if (filters.status != null && t.status != filters.status) return false;
      if (filters.key != null &&
          filters.key!.isNotEmpty &&
          t.key != filters.key) {
        return false;
      }
      if (query.isNotEmpty && !normalizeForSearch(t.name).contains(query)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (filters.sort) {
        case TuneSort.grouped:
          // Section by genre (canonical order), then type (tradition order),
          // then name — the default glanceable view.
          final ga = sectionGenreLabel(a.genre);
          final gb = sectionGenreLabel(b.genre);
          final gr = _genreRank(ga).compareTo(_genreRank(gb));
          if (gr != 0) return gr;
          final gl = ga.toLowerCase().compareTo(gb.toLowerCase());
          if (gl != 0) return gl;
          final tr = _typeRank(a.type).compareTo(_typeRank(b.type));
          if (tr != 0) return tr;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case TuneSort.newestFirst:
        case TuneSort.oldestFirst:
          final ta = a.modifiedAt ?? a.createdAt;
          final tb = b.modifiedAt ?? b.createdAt;
          final cmp = ta.compareTo(tb);
          return filters.sort == TuneSort.newestFirst ? -cmp : cmp;
        case TuneSort.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case TuneSort.nameZA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case TuneSort.statusTodoFirst:
        case TuneSort.statusMasteredFirst:
          // Unset status counts as the least-learned (rank 0). Break ties by
          // name so the order within a status group is stable.
          final ra = a.status?.progressionRank ?? 0;
          final rb = b.status?.progressionRank ?? 0;
          if (ra != rb) {
            return filters.sort == TuneSort.statusTodoFirst
                ? ra.compareTo(rb)
                : rb.compareTo(ra);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  });
});

/// Distinct, non-empty keys present in the current tune library, sorted
/// for stable dropdown ordering. Reads from `allTunesProvider` so it
/// reacts to inserts/deletes.
final availableKeysProvider = Provider.autoDispose<List<String>>((ref) {
  final activeSourceIds = ref.watch(activeSourceIdsProvider);
  final allAsync = ref.watch(allTunesProvider);
  return allAsync.maybeWhen(
    data: (tunes) {
      final keys = <String>{
        for (final t in tunes)
          if (isSourceIdVisible(t.source, activeSourceIds) &&
              t.key != null &&
              t.key!.trim().isNotEmpty)
            t.key!.trim(),
      };
      final list = keys.toList()..sort();
      return list;
    },
    orElse: () => const <String>[],
  );
});

/// Distinct, non-empty genres present in the current tune library, sorted
/// for stable dropdown ordering. Reads from `allTunesProvider` so it
/// reacts to inserts/deletes.
final availableGenresProvider = Provider.autoDispose<List<String>>((ref) {
  final activeSourceIds = ref.watch(activeSourceIdsProvider);
  final allAsync = ref.watch(allTunesProvider);
  return allAsync.maybeWhen(
    data: (tunes) {
      final genres = <String>{
        for (final t in tunes)
          if (isSourceIdVisible(t.source, activeSourceIds) &&
              t.genre != null &&
              t.genre!.trim().isNotEmpty)
            t.genre!.trim(),
      };
      final list = genres.toList()..sort();
      return list;
    },
    orElse: () => const <String>[],
  );
});
