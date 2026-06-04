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
    final settingId = e['setting_id'];
    final rawDate = e['date'] as String?;
    return RemoteTune(
      name: e['name'] as String,
      type: _safeType(e['type'] as String?),
      key: e['key'] as String?,
      genre: e['genre'] as String?,
      abc: e['abc'] as String?,
      sourceName: sourceName,
      sourceId: id != null ? '$id' : null,
      settingId: settingId is int ? settingId : int.tryParse('$settingId'),
      date: rawDate != null ? DateTime.tryParse(rawDate) : null,
      contributor: e['by'] as String?,
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

  /// Registry id (e.g. 'paulhardy') stamped onto imported tunes as their
  /// licensing provenance ([Tune.source]). Comes from [ContentSourceMeta.id].
  final String sourceId;

  /// Genre applied to imported tunes that don't carry their own genre, so a
  /// repository's tunes are categorized by its cultural/geographic genre
  /// (e.g. 'Irish', 'Scottish') unless the source data overrides it.
  final String? defaultGenre;

  final String _assetPath;
  List<RemoteTune>? _cache;

  StaticAssetTuneSource({
    required this.name,
    required this.sourceId,
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

  /// Maximum number of distinct tunes returned per search. A tune may carry
  /// several settings (e.g. thesession.org), all of which are kept — so the
  /// cap counts tunes, not rows, to avoid chopping a tune's settings in half.
  static const _maxTunes = 20;

  @override
  Future<List<RemoteTune>> search(
    String query, {
    String? type,
    String? key,
  }) async {
    final all = await _load();
    final q = normalizeForSearch(query);
    final matches = all.where((t) => normalizeForSearch(t.name).contains(q));
    final seenTunes = <String>{};
    final result = <RemoteTune>[];
    for (final t in matches) {
      // Group settings by their tune. `sourceId` is the tune id; results that
      // lack one (single-version sources) each count as their own tune.
      final tuneKey = t.sourceId ?? 'noid:${t.name}:${result.length}';
      if (!seenTunes.contains(tuneKey)) {
        if (seenTunes.length >= _maxTunes) break;
        seenTunes.add(tuneKey);
      }
      result.add(t);
    }
    return result;
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
      // Provenance for licensing. `from` ("learned from") is left null — the
      // user fills that in if and when they learn the tune from someone.
      source: drift.Value(sourceId),
      tsId: drift.Value(tsId),
    );
  }
}
