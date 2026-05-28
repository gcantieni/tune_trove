// One-time script to produce assets/data/oneills_1001_tunes.json from John Chambers'
// O'Neill's 1001 transcription (transcribed by Frank Nordberg).
//
// Usage:
//   dart lib/remote_tune_sources/oneills_1001_scrape.dart
//
// Fetches all 1001 numbered ABC files from the X/ directory and writes a JSON
// array of {name, type, key, abc} objects to assets/data/oneills_1001_tunes.json.
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://trillian.mit.edu/~jc/music/book/ONeills/_1001/X/';
const _count = 1001;
const _outPath = 'assets/data/oneills_1001_tunes.json';

void main() async {
  final client = http.Client();
  try {
    final tunes = <Map<String, dynamic>>[];

    for (var i = 1; i <= _count; i++) {
      final filename = i.toString().padLeft(4, '0') + '.abc';
      final url = Uri.parse('$_baseUrl$filename');
      final response = await client.get(url);
      if (response.statusCode != 200) {
        stderr.writeln('Skipping $filename (${response.statusCode})');
        continue;
      }
      final parsed = _parseTune(response.body);
      if (parsed != null) tunes.add(parsed);
      if (i % 100 == 0) stdout.writeln('Fetched $i / $_count ...');
    }

    stdout.writeln('Parsed ${tunes.length} tunes');
    File(_outPath).writeAsStringSync(jsonEncode(tunes));
    stdout.writeln('Wrote $_outPath');
  } finally {
    client.close();
  }
}

Map<String, dynamic>? _parseTune(String abcContent) {
  final name = _field(abcContent, 'T');
  final rawType = _field(abcContent, 'R');
  final key = _field(abcContent, 'K');
  if (name == null) return null;
  return {
    'name': name,
    'type': _normalizeType(rawType),
    'key': key ?? '',
    'abc': abcContent.trim(),
  };
}

// Map O'Neill's R: field variants to the canonical lowercase type strings
// expected by stringToType(). Unknown/compound types become empty string
// (which resolves to null type in the app — acceptable).
String _normalizeType(String? raw) {
  if (raw == null) return '';
  final lower = raw.toLowerCase();
  if (lower.contains('double jig') || lower == 'jig') return 'jig';
  if (lower.contains('single jig')) return 'jig';
  if (lower.contains('slip jig')) return 'slip jig';
  if (lower.contains('reel')) return 'reel';
  if (lower.contains('hornpipe')) return 'hornpipe';
  if (lower.contains('polka')) return 'polka';
  if (lower.contains('slide')) return 'slide';
  if (lower.contains('march')) return 'march';
  if (lower.contains('waltz')) return 'waltz';
  if (lower.contains('strathspey')) return 'strathspey';
  if (lower.contains('mazurka')) return 'mazurka';
  return '';
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
