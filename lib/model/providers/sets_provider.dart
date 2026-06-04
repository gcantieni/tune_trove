import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';

final allSetsProvider = StreamProvider.autoDispose<List<TuneSet>>((ref) {
  return ref.watch(databaseProvider).setDao.watchAllSets();
});

final singleSetProvider = StreamProvider.family.autoDispose<TuneSet?, int>((
  ref,
  id,
) {
  return ref.watch(databaseProvider).setDao.watchSet(id);
});

final setTunesProvider = StreamProvider.family
    .autoDispose<List<SetTuneEntry>, int>((ref, setId) {
      return ref.watch(databaseProvider).setTuneDao.watchTunesInSet(setId);
    });

/// Like [setTunesProvider] but hides entries whose source is not currently
/// active. Rebuilds automatically when the user confirms or revokes a source.
final visibleSetTunesProvider = StreamProvider.family
    .autoDispose<List<SetTuneEntry>, int>((ref, setId) {
      final activeSourceIds = ref.watch(activeSourceIdsProvider);
      return ref
          .watch(databaseProvider)
          .setTuneDao
          .watchTunesInSet(setId)
          .map(
            (entries) => entries
                .where((e) => isSourceIdVisible(e.tune.source, activeSourceIds))
                .toList(),
          );
    });

final setsForTuneProvider = StreamProvider.family
    .autoDispose<List<TuneSetEntry>, int>((ref, tuneId) {
      return ref.watch(databaseProvider).setTuneDao.watchSetsForTune(tuneId);
    });
