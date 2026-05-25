import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/source_confirmation_service.dart';
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

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final sourceConfirmationServiceProvider = Provider<SourceConfirmationService>((
  ref,
) {
  return SourceConfirmationService(ref.watch(sharedPreferencesProvider));
});

// ---------------------------------------------------------------------------
// Confirmation state — reactive so tuneSourcesProvider rebuilds on change
// ---------------------------------------------------------------------------

class ConfirmedSourcesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return ref.watch(sourceConfirmationServiceProvider).confirmedIds();
  }

  Future<void> confirm(String sourceId, String license) async {
    await ref
        .read(sourceConfirmationServiceProvider)
        .confirm(sourceId, license);
    // Re-read from prefs to stay in sync with any external mutations.
    state = ref.read(sourceConfirmationServiceProvider).confirmedIds();
  }

  Future<void> revoke(String sourceId) async {
    await ref.read(sourceConfirmationServiceProvider).revoke(sourceId);
    state = ref.read(sourceConfirmationServiceProvider).confirmedIds();
  }
}

final confirmedSourcesProvider =
    NotifierProvider<ConfirmedSourcesNotifier, Set<String>>(
      ConfirmedSourcesNotifier.new,
    );

// ---------------------------------------------------------------------------
// Content-gated tune sources
// ---------------------------------------------------------------------------

/// Returns only the [TuneSource]s whose license terms the user has accepted
/// (or which are always active because they require no confirmation).
/// Rebuilds automatically when the user confirms or revokes a source.
final tuneSourcesProvider = Provider<List<TuneSource>>((ref) {
  final client = ref.watch(httpClientProvider);
  final confirmedIds = ref.watch(confirmedSourcesProvider);

  return allContentSources
      .where((meta) => meta.isAlwaysActive || confirmedIds.contains(meta.id))
      .map((meta) => buildTuneSource(meta, client: client))
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
