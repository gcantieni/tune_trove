/// Ensures an ABC string carries a key signature.
///
/// Some sources (notably thesession.org) return the tune *body* with the key
/// in a separate field, so the stored ABC has no `K:` header. abcjs then
/// assumes C major — the notation renders without accidentals and the MIDI
/// plays in the wrong mode (e.g. a D major tune sounds natural-minor-ish). When
/// the ABC already declares a key this returns it unchanged; otherwise it
/// injects a `K:` line (and, when absent, the minimal `X:`/`M:`/`L:` fields a
/// standalone ABC tune needs) derived from [key].
///
/// [key] is the app's stored key string (e.g. "Dmaj", "Edorian", "Gmajor"). If
/// it can't be parsed, or is null/empty, the ABC is returned unchanged. A
/// null/blank [abc] is returned as-is (nullability preserved).
String? assembleAbc(String? abc, {String? key}) {
  if (abc == null || abc.trim().isEmpty) return abc;
  final body = abc;
  // Already has a key — nothing to do (idempotent for full ABC and repeated
  // calls).
  if (_hasField(body, 'K')) return body;
  final abcKey = normalizeKeyForAbc(key);
  if (abcKey == null) return body;

  // Build only the header fields the body is missing, so we don't duplicate an
  // existing X:/M:/L: from a partial header.
  final header = StringBuffer();
  if (!_hasField(body, 'X')) header.writeln('X:1');
  if (!_hasField(body, 'M')) header.writeln('M:4/4');
  if (!_hasField(body, 'L')) header.writeln('L:1/8');
  header.writeln('K:$abcKey');
  return '$header${body.startsWith('\n') ? body.substring(1) : body}';
}

bool _hasField(String abc, String tag) =>
    RegExp('^$tag:', multiLine: true).hasMatch(abc);

/// Converts a stored key string into an ABC `K:` value, e.g. "Gmajor" → "Gmaj",
/// "Edorian" → "Edor", "Dmaj" → "Dmaj". Returns null when [key] is null, empty,
/// or has no recognizable tonic.
///
/// abcjs accepts a tonic (A–G with optional #/b) followed by an abbreviated
/// mode (maj/min/dor/mix/lyd/phr/loc). thesession.org spells modes out in full
/// ("major", "dorian"), so we normalize to the short forms.
String? normalizeKeyForAbc(String? key) {
  if (key == null) return null;
  final trimmed = key.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^([A-Ga-g])([#b♯♭]?)\s*(.*)$').firstMatch(trimmed);
  if (match == null) return null;
  final tonic = match.group(1)!.toUpperCase();
  final accidental = switch (match.group(2)) {
    '♯' => '#',
    '♭' => 'b',
    final a => a ?? '',
  };
  final mode = _abbreviateMode(match.group(3)!);
  return '$tonic$accidental$mode';
}

/// Maps a (possibly spelled-out) mode to the abbreviation abcjs expects. An
/// empty/major mode yields '' (a bare tonic is major in ABC).
String _abbreviateMode(String raw) {
  final m = raw.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
  switch (m) {
    case '':
    case 'maj':
    case 'major':
    case 'ion':
    case 'ionian':
      return '';
    case 'm':
    case 'min':
    case 'minor':
    case 'aeo':
    case 'aeolian':
      return 'min';
    case 'dor':
    case 'dorian':
      return 'dor';
    case 'mix':
    case 'mixo':
    case 'mixolydian':
      return 'mix';
    case 'lyd':
    case 'lydian':
      return 'lyd';
    case 'phr':
    case 'phrygian':
      return 'phr';
    case 'loc':
    case 'locrian':
      return 'loc';
    default:
      // Unknown mode word — fall back to the abcjs-safe short form if it's
      // already an accepted token, otherwise treat as major.
      const known = {'maj', 'min', 'dor', 'mix', 'lyd', 'phr', 'loc'};
      return known.contains(m) ? m : '';
  }
}
