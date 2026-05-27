// One-time script to produce assets/data/aird_tunes.json from Jack Campin's
// ABC transcriptions of the James Aird Collection (6 volumes, 1778/1782).
//
// Usage:
//   dart lib/remote_tune_sources/aird_scrape.dart
//
// Downloads the abc2 (canonical) edition of each volume from trillian.mit.edu,
// concatenates them, and writes assets/data/aird_tunes.json in the standard
// {name, type, key, abc} format. Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://trillian.mit.edu/~jc/music/book/Aird/';
const _outPath = 'assets/data/aird_tunes.json';

void main() async {
  final client = http.Client();
  try {
    final buffer = StringBuffer();
    // abc2 is the canonical edition (no BarFly-specific directives, standard
    // grace-note notation); abc1 contains the same tunes in an older format.
    for (var vol = 1; vol <= 6; vol++) {
      final filename = 'Aird_vol${vol}_abc2.abc';
      final url = Uri.parse('$_baseUrl$filename');
      stdout.writeln('Downloading $filename ...');
      final response = await client.get(url);
      if (response.statusCode != 200) {
        stderr.writeln('Download failed: ${response.statusCode}');
        exit(1);
      }
      buffer.write(response.body);
      if (!response.body.endsWith('\n')) buffer.write('\n');
    }

    final tunes = _parseTunes(buffer.toString());
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
    if (name == null) continue;
    tunes.add({
      'name': name,
      'type': _normalizeType(_field(fullAbc, 'R')),
      'key': _field(fullAbc, 'K') ?? '',
      'abc': fullAbc,
    });
  }
  return tunes;
}

String _normalizeType(String? raw) {
  if (raw == null) return '';
  final lower = raw.toLowerCase();
  if (lower.contains('reel')) return 'reel';
  if (lower.contains('jig')) return 'jig';
  if (lower.contains('hornpipe')) return 'hornpipe';
  if (lower.contains('march')) return 'march';
  if (lower.contains('strathspey')) return 'strathspey';
  if (lower.contains('waltz')) return 'waltz';
  if (lower.contains('polka')) return 'polka';
  if (lower.contains('mazurka')) return 'mazurka';
  if (lower.contains('slide')) return 'slide';
  if (lower.contains('slip jig')) return 'slip jig';
  return '';
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
