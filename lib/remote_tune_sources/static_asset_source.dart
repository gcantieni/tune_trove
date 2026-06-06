import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/thesession_tune_source.dart'
    show stringToType;
import 'package:tune_trove/remote_tune_sources/tune_source.dart';
import 'package:tune_trove/util/abc_assembly.dart';
import 'package:tune_trove/util/search_normalize.dart';

List<RemoteTune> parseStaticJson(
  List<Map<String, dynamic>> data,
  String sourceName,
) {
  return data.map((e) {
    final id = e['id'];
    final settingId = e['setting_id'];
    final rawDate = e['date'] as String?;
    final key = e['key'] as String?;
    return RemoteTune(
      name: e['name'] as String,
      type: _safeType(e['type'] as String?),
      key: key,
      genre: e['genre'] as String?,
      // Many downloaded collections (notably thesession.org) store the tune
      // body with the key in a separate field. Inject a K: header so the
      // notation renders with the right accidentals and the MIDI plays in the
      // correct mode instead of defaulting to C major.
      abc: assembleAbc(e['abc'] as String?, key: key),
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

/// Maximum number of distinct tunes returned per search. A tune may carry
/// several settings (e.g. thesession.org), all of which are kept — so the cap
/// counts tunes, not rows, to avoid chopping a tune's settings in half.
const _maxTunes = 20;

/// Searches [all] for tunes whose name contains [query].
///
/// On thesession.org a single tune (one [RemoteTune.sourceId]) can have
/// settings filed under different names. So rather than returning only the rows
/// whose name matched, we collect the matched *tune ids* and then reverse-look
/// up **every** setting sharing those ids — surfacing alternate transcriptions
/// even when they're recorded under a different name. Rows without a sourceId
/// (single-version sources) have no siblings and are returned as-is.
///
/// At most [maxTunes] distinct tunes are returned (all of each tune's settings
/// are kept). Order: name-matched tunes in order of first appearance, then each
/// tune's settings in source order.
List<RemoteTune> searchTunes(
  List<RemoteTune> all,
  String query, {
  int maxTunes = _maxTunes,
}) {
  final q = normalizeForSearch(query);

  // Distinct tune ids whose name matched, in first-appearance order, plus the
  // name-matched rows that have no tune id (kept verbatim). Together capped at
  // [maxTunes] tunes.
  final matchedIds = <String>{};
  final orderedIds = <String>[];
  final looseMatches = <RemoteTune>[];
  for (final t in all) {
    if (matchedIds.length + looseMatches.length >= maxTunes) break;
    if (!normalizeForSearch(t.name).contains(q)) continue;
    final id = t.sourceId;
    if (id == null) {
      looseMatches.add(t);
    } else if (matchedIds.add(id)) {
      orderedIds.add(id);
    }
  }

  if (matchedIds.isEmpty) return looseMatches;

  // Reverse lookup: gather all settings for each matched tune id, preserving
  // the matched-tune order and source (setting) order within each tune.
  final byId = <String, List<RemoteTune>>{};
  for (final t in all) {
    final id = t.sourceId;
    if (id != null && matchedIds.contains(id)) {
      (byId[id] ??= []).add(t);
    }
  }
  return [
    ...looseMatches,
    for (final id in orderedIds) ...?byId[id],
  ];
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

  @override
  Future<List<RemoteTune>> search(
    String query, {
    String? type,
    String? key,
  }) async {
    final all = await _load();
    return searchTunes(all, query);
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
