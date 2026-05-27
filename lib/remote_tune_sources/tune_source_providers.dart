import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/model/accessors/source_confirmation_dao.dart';
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
// Confirmation state — single source of truth for all active sources.
//
// Public-domain sources are auto-confirmed on first encounter (seeded via
// SharedPreferences tracking so user revocations are never overwritten).
// Licensed sources start unconfirmed and require the user to accept terms.
//
// Watching the DAO stream means a confirmation synced in from another device
// activates the source live without any further action.
// ---------------------------------------------------------------------------

/// SharedPreferences key tracking which source IDs have ever been auto-seeded.
/// Once an ID appears here we never seed it again, preserving user revocations.
const _seededKey = 'seeded_source_ids';

/// Idempotently confirms every public-domain source that has not yet been
/// seeded on this device. Called once on startup; safe to call multiple times.
Future<void> _seedNewPublicDomainSources(
  SourceConfirmationDao dao,
  SharedPreferences prefs,
) async {
  final seeded = (prefs.getStringList(_seededKey) ?? []).toSet();
  final toSeed = allContentSources
      .where(
        (m) => !m.confirmationRequired && !m.hidden && !seeded.contains(m.id),
      )
      .toList();
  if (toSeed.isEmpty) return;
  for (final meta in toSeed) {
    await dao.confirm(meta.id, meta.license);
  }
  await prefs.setStringList(_seededKey, [
    ...seeded,
    ...toSeed.map((m) => m.id),
  ]);
}

class ConfirmedSourcesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final dao = ref.watch(databaseProvider).sourceConfirmationDao;
    final prefs = ref.read(sharedPreferencesProvider);
    // Seed any newly-added public-domain sources on this device.
    unawaited(_seedNewPublicDomainSources(dao, prefs));
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
      if (!m.hidden && confirmedIds.contains(m.id)) m.name,
  };
});

// ---------------------------------------------------------------------------
// Content-gated tune sources
// ---------------------------------------------------------------------------

/// Returns only the [TuneSource]s the user currently has active.
/// Rebuilds automatically when the user confirms or revokes a source.
final tuneSourcesProvider = Provider<List<TuneSource>>((ref) {
  final confirmedIds = ref.watch(confirmedSourcesProvider);
  return allContentSources
      .where((meta) => !meta.hidden && confirmedIds.contains(meta.id))
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
