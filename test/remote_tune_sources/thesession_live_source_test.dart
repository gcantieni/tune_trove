import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tune_trove/model/tables/tunes.dart' show TuneType;
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/thesession_live_source.dart';

class _FakeClient extends http.BaseClient {
  final Map<String, String> responses;
  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = responses[request.url.toString()];
    if (body == null) {
      return http.StreamedResponse(const Stream.empty(), 404);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

const _searchResponse = '{"tunes":[{"id":1,"name":"Cooley\'s","type":"reel"},{"id":2,"name":"Cooley\'s Minor","type":"reel"}]}';

const _tuneResponse = '{"id":1,"name":"Cooley\'s","type":"reel","settings":[{"id":1,"abc":"K:Edor\\n|:D2|EBBA","key":"Edor"}]}';

void main() {
  group('TheSessionTuneSource.search', () {
    test('returns RemoteTunes from API response', () async {
      final client = _FakeClient({
        'https://thesession.org/tunes/search?q=cooley&format=json': _searchResponse,
      });
      final source = TheSessionTuneSource(client: client);

      final results = await source.search('cooley');

      expect(results, hasLength(2));
      expect(results[0].name, "Cooley's");
      expect(results[0].sourceName, 'thesession.org');
      expect(results[0].sourceId, '1');
      expect(results[0].abc, isNull);
      expect(results[0].type, TuneType.reel);
    });

    test('returns empty list on non-200 response', () async {
      final client = _FakeClient({});
      final source = TheSessionTuneSource(client: client);

      final results = await source.search('cooley');

      expect(results, isEmpty);
    });

    test('passes type and key params', () async {
      String? capturedUrl;
      final capturingClient = _CapturingClient((url) {
        capturedUrl = url;
        return _searchResponse;
      });
      final source = TheSessionTuneSource(client: capturingClient);

      await source.search('cooley', type: 'reel', key: 'Edor');

      expect(capturedUrl, contains('type=reel'));
      expect(capturedUrl, contains('mode=Edor'));
    });
  });

  group('TheSessionTuneSource.resolve', () {
    const cooleys = RemoteTune(
      name: "Cooley's",
      sourceName: 'thesession.org',
      sourceId: '1',
      type: TuneType.reel,
    );

    test('fetches ABC and returns TunesCompanion', () async {
      final client = _FakeClient({
        'https://thesession.org/tunes/1?format=json': _tuneResponse,
      });
      final source = TheSessionTuneSource(client: client);

      final companion = await source.resolve(cooleys);

      expect(companion.name.value, "Cooley's");
      expect(companion.tsId.value, 1);
      expect(companion.abc.value, contains('Edor'));
      expect(companion.key.value, 'Edor');
      expect(companion.from.value, 'thesession.org');
    });

    test('throws on non-200 settings response', () {
      final client = _FakeClient({});
      final source = TheSessionTuneSource(client: client);

      expect(source.resolve(cooleys), throwsException);
    });
  });
}

class _CapturingClient extends http.BaseClient {
  final String Function(String url) _handler;
  _CapturingClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = _handler(request.url.toString());
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
