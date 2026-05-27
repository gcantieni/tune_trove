// One-time script to produce assets/data/athole_tunes.json from the Athole
// Collection ABC transcription hosted at trillian.mit.edu.
//
// "The Athole Collection" (1884), compiled by James Stewart-Robertson.
// Transcribed anonymously; hosted by John Chambers.
//
// The collection is split alphabetically across five files in the F/
// sub-directory, covering all 870 tunes.
//
// Usage:
//   dart lib/remote_tune_sources/athole_scrape.dart
//
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://trillian.mit.edu/~jc/music/book/Athole/F/';
const _files = [
  'athol-ad.abc',
  'athol-eh.abc',
  'athol-il.abc',
  'athol-m.abc',
  'athol-nz.abc',
];
const _outPath = 'assets/data/athole_tunes.json';

void main() async {
  final client = http.Client();
  try {
    final buffer = StringBuffer();
    for (final filename in _files) {
      final url = Uri.parse('$_baseUrl$filename');
      stdout.writeln('Downloading $filename...');
      final response = await client.get(url);
      if (response.statusCode != 200) {
        stderr.writeln('Download failed for $filename: ${response.statusCode}');
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
  if (lower.contains('strathsp')) return 'strathspey';
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
