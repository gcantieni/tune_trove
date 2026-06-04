import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/model/accessors/source_confirmation_dao.dart';
import 'package:tune_trove/model/accessors/source_rankings_dao.dart';
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
  SourceRankingsDao rankingsDao,
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
    await rankingsDao.appendSource(meta.id);
  }
  await prefs.setStringList(_seededKey, [
    ...seeded,
    ...toSeed.map((m) => m.id),
  ]);
}

class ConfirmedSourcesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final db = ref.watch(databaseProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    // Seed any newly-added public-domain sources on this device.
    unawaited(
      _seedNewPublicDomainSources(
        db.sourceConfirmationDao,
        db.sourceRankingsDao,
        prefs,
      ),
    );
    final sub = db.sourceConfirmationDao.watchConfirmedIds().listen(
      (ids) => state = ids,
    );
    ref.onDispose(sub.cancel);
    return const {};
  }

  Future<void> confirm(String sourceId, String license) async {
    final db = ref.read(databaseProvider);
    await db.sourceConfirmationDao.confirm(sourceId, license);
    await db.sourceRankingsDao.appendSource(sourceId);
  }

  Future<void> revoke(String sourceId) async {
    final db = ref.read(databaseProvider);
    await db.sourceConfirmationDao.revoke(sourceId);
    await db.sourceRankingsDao.removeSource(sourceId);
  }
}

final confirmedSourcesProvider =
    NotifierProvider<ConfirmedSourcesNotifier, Set<String>>(
      ConfirmedSourcesNotifier.new,
    );

// ---------------------------------------------------------------------------
// Active source ids — used to gate tune display in the library and sets
// ---------------------------------------------------------------------------

/// The set of source ids whose content is currently permitted to display.
/// Rebuilds reactively whenever the user confirms or revokes a source.
///
/// Pass [Tune.source] to [isSourceIdVisible] together with this set to decide
/// whether a given tune should be shown. Hidden sources are excluded (their
/// content stays gated even once confirmed), matching the prior name-based set.
final activeSourceIdsProvider = Provider<Set<String>>((ref) {
  final confirmedIds = ref.watch(confirmedSourcesProvider);
  return {
    for (final m in allContentSources)
      if (!m.hidden && confirmedIds.contains(m.id)) m.id,
  };
});

// ---------------------------------------------------------------------------
// Source ranking — user-controlled search-result order
// ---------------------------------------------------------------------------

/// Ordered list of active source IDs as the user has ranked them.
/// Lower index = appears first in search results.
final sourceRankOrderProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(databaseProvider).sourceRankingsDao.watchRankedSourceIds();
});

// ---------------------------------------------------------------------------
// Content-gated tune sources
// ---------------------------------------------------------------------------

/// Returns only the [TuneSource]s the user currently has active, sorted by
/// the user's saved rank ([sourceRankOrderProvider]).
/// Rebuilds automatically when the user confirms, revokes, or reorders sources.
final tuneSourcesProvider = Provider<List<TuneSource>>((ref) {
  final confirmedIds = ref.watch(confirmedSourcesProvider);
  final rankedIds = ref.watch(sourceRankOrderProvider).value ?? [];

  final activeSources = allContentSources
      .where((meta) => !meta.hidden && confirmedIds.contains(meta.id))
      .toList();

  activeSources.sort((a, b) {
    final aIdx = rankedIds.indexOf(a.id);
    final bIdx = rankedIds.indexOf(b.id);
    if (aIdx == -1 && bIdx == -1) return 0;
    if (aIdx == -1) return 1;
    if (bIdx == -1) return -1;
    return aIdx.compareTo(bIdx);
  });

  return activeSources.map(buildTuneSource).toList();
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
