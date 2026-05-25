import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/static_asset_source.dart';
import 'package:tune_trove/remote_tune_sources/thesession_live_source.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tuneSourcesProvider = Provider<List<TuneSource>>((ref) {
  final client = ref.watch(httpClientProvider);
  return [
    TheSessionTuneSource(client: client),
    StaticAssetTuneSource(
      name: "O'Neill's 1001",
      assetPath: 'assets/data/oneills_tunes.json',
    ),
    StaticAssetTuneSource(
      name: 'Norbeck',
      assetPath: 'assets/data/norbeck_tunes.json',
    ),
    StaticAssetTuneSource(
      name: 'William Clarke of Feltwell',
      assetPath: 'assets/data/williamclarke_tunes.json',
    ),
    StaticAssetTuneSource(
      name: 'Paul Hardy Session Tunebook',
      assetPath: 'assets/data/paulhardy_tunes.json',
    ),
    StaticAssetTuneSource(
      name: 'Pete Mac Tunebook',
      assetPath: 'assets/data/pete_mac_tunes.json',
    ),
  ];
});

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
