import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/util/search_normalize.dart';

enum TuneSort { newestFirst, oldestFirst, nameAZ, nameZA }

class TuneFilters {
  final TuneType? type;
  final String? key;
  final String nameQuery;
  final TuneSort sort;

  const TuneFilters({
    this.type,
    this.key,
    this.nameQuery = '',
    this.sort = TuneSort.newestFirst,
  });

  bool get isActive =>
      type != null ||
      (key != null && key!.isNotEmpty) ||
      nameQuery.isNotEmpty ||
      sort != TuneSort.newestFirst;

  TuneFilters copyWith({
    Object? type = _sentinel,
    Object? key = _sentinel,
    String? nameQuery,
    TuneSort? sort,
  }) {
    return TuneFilters(
      type: identical(type, _sentinel) ? this.type : type as TuneType?,
      key: identical(key, _sentinel) ? this.key : key as String?,
      nameQuery: nameQuery ?? this.nameQuery,
      sort: sort ?? this.sort,
    );
  }
}

const _sentinel = Object();

class TuneFiltersNotifier extends Notifier<TuneFilters> {
  @override
  TuneFilters build() => const TuneFilters();

  void setType(TuneType? type) => state = state.copyWith(type: type);
  void setKey(String? key) => state = state.copyWith(key: key);
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
  final allAsync = ref.watch(allTunesProvider);
  return allAsync.whenData((all) {
    final query = normalizeForSearch(filters.nameQuery.trim());
    final filtered = all.where((t) {
      if (filters.type != null && t.type != filters.type) return false;
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
      }
    });

    return filtered;
  });
});

/// Distinct, non-empty keys present in the current tune library, sorted
/// for stable dropdown ordering. Reads from `allTunesProvider` so it
/// reacts to inserts/deletes.
final availableKeysProvider = Provider.autoDispose<List<String>>((ref) {
  final allAsync = ref.watch(allTunesProvider);
  return allAsync.maybeWhen(
    data: (tunes) {
      final keys = <String>{
        for (final t in tunes)
          if (t.key != null && t.key!.trim().isNotEmpty) t.key!.trim(),
      };
      final list = keys.toList()..sort();
      return list;
    },
    orElse: () => const <String>[],
  );
});
