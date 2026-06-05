import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';
import 'package:tune_trove/model/providers/tune_recording_provider.dart';

enum RecordingSort { dateAdded, nameAZ, nameZA }

/// Whether to show recordings linked to a tune, not linked, or both.
enum TuneLinkFilter { any, hasTune, noTune }

/// Filter/sort state for the Recordings list.
class RecordingFilters {
  /// Restricts the list by tune-link state (linked / unlinked / both).
  final TuneLinkFilter tuneLink;
  final RecordingSort sort;

  const RecordingFilters({
    this.tuneLink = TuneLinkFilter.any,
    this.sort = RecordingSort.dateAdded,
  });

  bool get isActive =>
      tuneLink != TuneLinkFilter.any || sort != RecordingSort.dateAdded;

  RecordingFilters copyWith({TuneLinkFilter? tuneLink, RecordingSort? sort}) {
    return RecordingFilters(
      tuneLink: tuneLink ?? this.tuneLink,
      sort: sort ?? this.sort,
    );
  }
}

/// Applies [filters] to [all]. [linkedRecordingIds] is the set of recording ids
/// that have at least one tune link; used for the "Has tune link" filter.
///
/// Kept a pure function (no providers) so it's trivially unit-testable, mirroring
/// the tune-list `filteredTunesProvider` design.
List<Recording> applyRecordingFilters(
  List<Recording> all,
  RecordingFilters filters,
  Set<int> linkedRecordingIds,
) {
  final filtered = switch (filters.tuneLink) {
    TuneLinkFilter.any => List<Recording>.of(all),
    TuneLinkFilter.hasTune => all
        .where((r) => linkedRecordingIds.contains(r.id))
        .toList(),
    TuneLinkFilter.noTune => all
        .where((r) => !linkedRecordingIds.contains(r.id))
        .toList(),
  };

  filtered.sort((a, b) {
    switch (filters.sort) {
      case RecordingSort.dateAdded:
        // Newest first.
        return b.createdAt.compareTo(a.createdAt);
      case RecordingSort.nameAZ:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case RecordingSort.nameZA:
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
    }
  });

  return filtered;
}

class RecordingFiltersNotifier extends Notifier<RecordingFilters> {
  @override
  RecordingFilters build() => const RecordingFilters();

  void setTuneLink(TuneLinkFilter value) =>
      state = state.copyWith(tuneLink: value);
  void setSort(RecordingSort sort) => state = state.copyWith(sort: sort);
  void clear() => state = const RecordingFilters();
}

final recordingFiltersProvider =
    NotifierProvider<RecordingFiltersNotifier, RecordingFilters>(
      RecordingFiltersNotifier.new,
    );

/// Recordings after the current filters and sort are applied. Filtering is done
/// in Dart because the collection is small.
final filteredRecordingsProvider =
    Provider.autoDispose<AsyncValue<List<Recording>>>((ref) {
      final filters = ref.watch(recordingFiltersProvider);
      final allAsync = ref.watch(allRecordingsProvider);
      final linkedIds = ref
          .watch(linkedRecordingIdsProvider)
          .maybeWhen(data: (ids) => ids, orElse: () => const <int>{});
      return allAsync.whenData(
        (all) => applyRecordingFilters(all, filters, linkedIds),
      );
    });
