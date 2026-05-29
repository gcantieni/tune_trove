import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/thesession_tune_source.dart'
    show stringToType;
import 'package:tune_trove/remote_tune_sources/tune_source.dart';
import 'package:tune_trove/util/search_normalize.dart';

List<RemoteTune> parseStaticJson(
  List<Map<String, dynamic>> data,
  String sourceName,
) {
  return data.map((e) {
    final id = e['id'];
    return RemoteTune(
      name: e['name'] as String,
      type: _safeType(e['type'] as String?),
      key: e['key'] as String?,
      genre: e['genre'] as String?,
      abc: e['abc'] as String?,
      sourceName: sourceName,
      sourceId: id != null ? '$id' : null,
    );
  }).toList();
}

TuneType? _safeType(String? s) {
  if (s == null) return null;
  try {
    return stringToType(s);
  } catch (_) {
    return null;
  }
}

class StaticAssetTuneSource implements TuneSource {
  @override
  final String name;

  /// Genre applied to imported tunes that don't carry their own genre, so a
  /// repository's tunes are categorized by its cultural/geographic genre
  /// (e.g. 'Irish', 'Scottish') unless the source data overrides it.
  final String? defaultGenre;

  final String _assetPath;
  List<RemoteTune>? _cache;

  StaticAssetTuneSource({
    required this.name,
    required String assetPath,
    this.defaultGenre,
  }) : _assetPath = assetPath;

  Future<List<RemoteTune>> _load() async {
    if (_cache != null) return _cache!;
    final raw = (jsonDecode(await rootBundle.loadString(_assetPath)) as List)
        .cast<Map<String, dynamic>>();
    _cache = parseStaticJson(raw, name);
    return _cache!;
  }

  @override
  Future<List<RemoteTune>> search(
    String query, {
    String? type,
    String? key,
  }) async {
    final all = await _load();
    final q = normalizeForSearch(query);
    return all
        .where((t) => normalizeForSearch(t.name).contains(q))
        .take(20)
        .toList();
  }

  @override
  Future<TunesCompanion> resolve(RemoteTune tune) async {
    final tsId = int.tryParse(tune.sourceId ?? '');
    // Fall back to the repository's genre, treating an empty default (sources
    // with no meaningful single genre) as "unset" rather than storing ''.
    final fallback = (defaultGenre?.isEmpty ?? true) ? null : defaultGenre;
    final genre = tune.genre ?? fallback;
    return TunesCompanion.insert(
      name: tune.name,
      createdAt: DateTime.now(),
      abc: drift.Value(tune.abc),
      key: drift.Value(tune.key),
      genre: drift.Value(genre),
      type: drift.Value(tune.type),
      from: drift.Value(name),
      tsId: drift.Value(tsId),
    );
  }
}
