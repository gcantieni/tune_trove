// One-time script to produce assets/data/neil_gow_tunes.json from John Chambers'
// ABC transcriptions of the Neil Gow & Sons Complete Repository (1799–1839).
//
// Usage:
//   dart lib/remote_tune_sources/neil_gow_scrape.dart <path-to-CR-abc2.abc>
//
// The combined CR-abc2.abc file (all 4 parts) from trillian.mit.edu is the
// expected input. Never compiled into the app.

import 'dart:convert';
import 'dart:io';

const _outPath = 'assets/data/neil_gow_tunes.json';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart neil_gow_scrape.dart <path-to-CR-abc2.abc>');
    exit(1);
  }
  final content = File(args[0]).readAsStringSync();
  final tunes = _parseTunes(content);
  stdout.writeln('Parsed ${tunes.length} tunes');
  File(_outPath).writeAsStringSync(jsonEncode(tunes));
  stdout.writeln('Wrote $_outPath');
}

List<Map<String, dynamic>> _parseTunes(String abcContent) {
  final tunes = <Map<String, dynamic>>[];
  final chunks = abcContent.split(RegExp('^X:', multiLine: true));
  for (final chunk in chunks) {
    if (chunk.trim().isEmpty) continue;
    final fullAbc = 'X:$chunk'.trim();
    final name = _field(fullAbc, 'T');
    if (name == null) continue;
    // Skip section-header pseudo-tunes (no actual notation).
    if (name.contains('COMPLETE REPOSITORY')) continue;
    tunes.add({
      'name': name,
      'type': _normalizeType(_rhythmField(fullAbc)),
      'key': _field(fullAbc, 'K') ?? '',
      'abc': fullAbc,
    });
  }
  return tunes;
}

// John Chambers uses %R: (a comment line) for rhythm, not the standard R: field.
String? _rhythmField(String abc) {
  final r = _field(abc, 'R');
  if (r != null) return r;
  final m = RegExp(r'^%R: *(.+)$', multiLine: true).firstMatch(abc);
  return m?.group(1)?.trim();
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
  if (lower.contains('scotch measure')) return 'scotch measure';
  return '';
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
