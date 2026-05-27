import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

/// Provided by main() via ProviderScope override after
/// SharedPreferences.getInstance() resolves.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

// ---------------------------------------------------------------------------
// Confirmation state — backed by the synced Drift table. Watching the DAO
// stream means a confirmation made (and synced in) from another device shows
// up live, activating its source here without re-confirming.
// ---------------------------------------------------------------------------

class ConfirmedSourcesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final dao = ref.watch(databaseProvider).sourceConfirmationDao;
    final sub = dao.watchConfirmedIds().listen((ids) => state = ids);
    ref.onDispose(sub.cancel);
    return const {};
  }

  Future<void> confirm(String sourceId, String license) => ref
      .read(databaseProvider)
      .sourceConfirmationDao
      .confirm(sourceId, license);

  Future<void> revoke(String sourceId) =>
      ref.read(databaseProvider).sourceConfirmationDao.revoke(sourceId);
}

final confirmedSourcesProvider =
    NotifierProvider<ConfirmedSourcesNotifier, Set<String>>(
      ConfirmedSourcesNotifier.new,
    );

// ---------------------------------------------------------------------------
// Active source names — used to gate tune display in the library and sets
// ---------------------------------------------------------------------------

/// The set of source names whose content is currently permitted to display.
/// Rebuilds reactively whenever the user confirms or revokes a source.
///
/// Pass [Tune.from] to [isSourceNameVisible] together with this set to decide
/// whether a given tune should be shown.
final activeSourceNamesProvider = Provider<Set<String>>((ref) {
  final confirmedIds = ref.watch(confirmedSourcesProvider);
  return {
    for (final m in allContentSources)
      if (!m.hidden && (m.isAlwaysActive || confirmedIds.contains(m.id)))
        m.name,
  };
});

// ---------------------------------------------------------------------------
// Content-gated tune sources
// ---------------------------------------------------------------------------

/// Returns only the [TuneSource]s whose license terms the user has accepted
/// (or which are always active because they require no confirmation).
/// Rebuilds automatically when the user confirms or revokes a source.
final tuneSourcesProvider = Provider<List<TuneSource>>((ref) {
  final confirmedIds = ref.watch(confirmedSourcesProvider);

  return allContentSources
      .where(
        (meta) =>
            !meta.hidden &&
            (meta.isAlwaysActive || confirmedIds.contains(meta.id)),
      )
      .map(buildTuneSource)
      .toList();
});

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

final tuneSearchProvider = FutureProvider.family
    .autoDispose<Map<String, List<RemoteTune>>, String>((ref, query) async {
      if (query.isEmpty) return {};
      final sources = ref.watch(tuneSourcesProvider);
      final entries = await Future.wait(
        sources.map((s) async {
          try {
            final tunes = await s.search(query);
            return MapEntry(s.name, tunes);
          } catch (_) {
            return MapEntry(s.name, <RemoteTune>[]);
          }
        }),
      );
      final result = <String, List<RemoteTune>>{};
      for (final e in entries) {
        if (e.value.isNotEmpty) result[e.key] = e.value;
      }
      return result;
    });
