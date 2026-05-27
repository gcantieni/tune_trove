// One-time script to produce assets/data/fraser_tunes.json from the Fraser
// Collection hosted at trillian.mit.edu/~jc/music/book/Fraser/T/.
//
// "Airs and Melodies Peculiar to the Highlands and The Isles"
// by Captain Simon Fraser, first published 1816.
//
// The T/ sub-directory holds one ABC file per tune, transcribed anonymously.
// John Chambers maintains the collection at trillian.mit.edu.
//
// Usage:
//   dart lib/remote_tune_sources/fraser_scrape.dart
//
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://trillian.mit.edu/~jc/music/book/Fraser/T/';
const _outPath = 'assets/data/fraser_tunes.json';

void main() async {
  final client = http.Client();
  try {
    stdout.writeln('Fetching directory listing...');
    final indexResp = await client.get(Uri.parse(_baseUrl));
    if (indexResp.statusCode != 200) {
      stderr.writeln('Failed to fetch index: ${indexResp.statusCode}');
      exit(1);
    }

    final filenames = RegExp(
      r'href="([^"]+\.abc)"',
    ).allMatches(indexResp.body).map((m) => m.group(1)!).toList();
    stdout.writeln('Found ${filenames.length} files');

    final tunes = <Map<String, dynamic>>[];
    for (final filename in filenames) {
      final url = Uri.parse('$_baseUrl$filename');
      http.Response? resp;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
          resp = await client.get(url);
          break;
        } catch (e) {
          if (attempt == 3) {
            stderr.writeln('Skipping $filename after 3 attempts: $e');
          }
        }
      }
      if (resp == null || resp.statusCode != 200) {
        if (resp != null) {
          stderr.writeln('Skipping $filename: HTTP ${resp.statusCode}');
        }
        continue;
      }
      final tune = _parseTune(resp.body.trim());
      if (tune != null) tunes.add(tune);
    }

    stdout.writeln('Parsed ${tunes.length} tunes');
    File(_outPath).writeAsStringSync(jsonEncode(tunes));
    stdout.writeln('Wrote $_outPath');
  } finally {
    client.close();
  }
}

Map<String, dynamic>? _parseTune(String abcContent) {
  // Each file is a single tune; use the first T: line as the name.
  final name = _field(abcContent, 'T');
  if (name == null) return null;
  return {
    'name': name,
    'type': _normalizeType(_field(abcContent, 'R')),
    'key': _field(abcContent, 'K') ?? '',
    'abc': abcContent,
  };
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
  // "Slow Air", "Air", "Slow Air or Waltz" — no matching TuneType
  return '';
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
