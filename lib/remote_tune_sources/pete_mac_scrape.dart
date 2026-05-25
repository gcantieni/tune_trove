// One-time script to produce assets/data/pete_mac_tunes.json from Paul Hardy's
// Pete Mac Tunebook ABC file (CC0 licensed).
//
// Usage:
//   dart lib/remote_tune_sources/pete_mac_scrape.dart
//
// Downloads the ABC file and writes assets/data/pete_mac_tunes.json in the
// standard {name, type, key, abc} format. Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _abcUrl = 'https://pghardy.net/tunebooks/pgh_pete_mac_tunebook.abc';
const _outPath = 'assets/data/pete_mac_tunes.json';

void main() async {
  final client = http.Client();
  try {
    stdout.writeln('Downloading $_abcUrl ...');
    final response = await client.get(Uri.parse(_abcUrl));
    if (response.statusCode != 200) {
      stderr.writeln('Download failed: ${response.statusCode}');
      exit(1);
    }

    final tunes = _parseTunes(response.body);
    stdout.writeln('Parsed ${tunes.length} tunes');
    File(_outPath).writeAsStringSync(jsonEncode(tunes));
    stdout.writeln('Wrote $_outPath');
  } finally {
    client.close();
  }
}

List<Map<String, dynamic>> _parseTunes(String abcContent) {
  final tunes = <Map<String, dynamic>>[];
  final chunks = abcContent.split(RegExp('^X:', multiLine: true));
  for (final chunk in chunks) {
    if (chunk.trim().isEmpty) continue;
    final fullAbc = 'X:$chunk'.trim();
    final name = _field(fullAbc, 'T');
    final type = _field(fullAbc, 'R');
    final key = _field(fullAbc, 'K');
    if (name == null) continue;
    tunes.add({
      'name': name,
      'type': type ?? '',
      'key': key ?? '',
      'abc': fullAbc,
    });
  }
  return tunes;
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
