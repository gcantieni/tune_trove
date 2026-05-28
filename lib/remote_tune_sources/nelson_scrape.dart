// One-time script to produce assets/data/nelson_tunes.json from John Chambers'
// ABC transcription of the Nelson Music Collection.
//
// "Selected Authentic Square Dance Melodies" (1969),
// compiled by Newton F. Tolman and K. Dep. Gilbert.
// Transcribed to ABC by Ralph Palmer. Courtesy of John Chambers.
//
// Usage:
//   dart lib/remote_tune_sources/nelson_scrape.dart
//
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _url = 'https://trillian.mit.edu/~jc/music/book/Nelson/nelson.abc';
const _outPath = 'assets/data/nelson_tunes.json';

void main() async {
  final client = http.Client();
  try {
    stdout.writeln('Downloading nelson.abc...');
    final response = await client.get(Uri.parse(_url));
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
    final key = _field(fullAbc, 'K');
    if (name == null || key == null) continue;
    tunes.add({
      'name': name,
      'type': _normalizeType(_field(fullAbc, 'R')),
      'key': key,
      'abc': fullAbc,
    });
  }
  return tunes;
}

String _normalizeType(String? raw) {
  if (raw == null) return '';
  final lower = raw.toLowerCase();
  if (lower.contains('strathspey')) return 'strathspey';
  if (lower.contains('slip')) return 'slip jig';
  if (lower.contains('reel')) return 'reel';
  if (lower.contains('jig')) return 'jig';
  if (lower.contains('hornpipe')) return 'hornpipe';
  if (lower.contains('march')) return 'march';
  if (lower.contains('waltz')) return 'waltz';
  if (lower.contains('polka')) return 'polka';
  if (lower.contains('mazurka')) return 'mazurka';
  if (lower.contains('slide')) return 'slide';
  return '';
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
