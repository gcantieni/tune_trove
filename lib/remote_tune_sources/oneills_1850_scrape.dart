// One-time script to produce assets/data/oneills_1850_tunes.json from
// John Chambers' ABC transcription of O'Neill's 1850.
//
// "O'Neill's Music of Ireland: Eighteen Hundred and Fifty Melodies"
// by Capt. Francis O'Neill (1903).
// Transcription copyrighted 1997-2000 by the contributors to the O'Neill's Project.
//
// Usage:
//   dart lib/remote_tune_sources/oneills_1850_scrape.dart
//
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://trillian.mit.edu/~jc/music/book/ONeills/_1850/F/';
const _outPath = 'assets/data/oneills_1850_tunes.json';

void main() async {
  final client = http.Client();
  try {
    stdout.writeln('Fetching directory listing...');
    final indexResponse = await client.get(Uri.parse(_baseUrl));
    if (indexResponse.statusCode != 200) {
      stderr.writeln('Index fetch failed: ${indexResponse.statusCode}');
      exit(1);
    }

    final files = RegExp(
      r'href="([^"]+\.abc)"',
    ).allMatches(indexResponse.body).map((m) => m.group(1)!).toList();

    stdout.writeln('Found ${files.length} files');

    final buffer = StringBuffer();
    for (final filename in files) {
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
  final seen = <String>{};
  final chunks = abcContent.split(RegExp('^X:', multiLine: true));
  for (final chunk in chunks) {
    if (chunk.trim().isEmpty) continue;
    final fullAbc = 'X:$chunk'.trim();
    final name = _field(fullAbc, 'T');
    final key = _field(fullAbc, 'K');
    if (name == null || key == null) continue;
    // The overlapping file ranges mean some tunes appear in multiple files.
    final dedupeKey = '$name|$key';
    if (!seen.add(dedupeKey)) continue;
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
