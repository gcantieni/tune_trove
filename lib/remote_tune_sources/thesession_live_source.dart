import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:http/http.dart' as http;
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart' show TuneType;
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/thesession_tune_source.dart'
    show stringToType;
import 'package:tune_trove/remote_tune_sources/tune_source.dart';

class TheSessionTuneSource implements TuneSource {
  final http.Client _client;

  TheSessionTuneSource({http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get name => 'thesession.org';

  @override
  Future<List<RemoteTune>> search(
    String query, {
    String? type,
    String? key,
  }) async {
    final params = <String, String>{'q': query, 'format': 'json'};
    if (type != null) params['type'] = type;
    if (key != null) params['mode'] = key;
    final uri = Uri.https('thesession.org', '/tunes/search', params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tunes = (data['tunes'] as List).cast<Map<String, dynamic>>();
    return tunes.map((t) {
      return RemoteTune(
        name: t['name'] as String,
        type: _safeType(t['type'] as String?),
        sourceName: name,
        sourceId: '${t['id']}',
        url: 'https://thesession.org/tunes/${t['id']}',
      );
    }).toList();
  }

  @override
  Future<TunesCompanion> resolve(RemoteTune tune) async {
    final uri = Uri.https('thesession.org', '/tunes/${tune.sourceId}', {
      'format': 'json',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'TheSession returned ${response.statusCode} for tune ${tune.sourceId}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final settings = (data['settings'] as List).cast<Map<String, dynamic>>();
    if (settings.isEmpty) {
      throw Exception('No settings found for tune ${tune.sourceId}');
    }
    final first = settings.first;
    final abc = first['abc'] as String;
    final key = first['key'] as String?;
    return TunesCompanion.insert(
      name: tune.name,
      createdAt: DateTime.now(),
      tsId: drift.Value(int.parse(tune.sourceId!)),
      abc: drift.Value(abc),
      key: drift.Value(key),
      type: drift.Value(tune.type),
      from: const drift.Value('thesession.org'),
    );
  }

  TuneType? _safeType(String? s) {
    if (s == null) return null;
    try {
      return stringToType(s);
    } catch (_) {
      return null;
    }
  }
}
