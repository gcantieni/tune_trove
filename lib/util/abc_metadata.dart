import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/model/tune_genres.dart';

/// Tune metadata inferred from ABC header information fields.
///
/// ABC tunes carry informational header fields that mirror what the app stores
/// as separate columns: `R:` (rhythm → [TuneType]), `C:` (composer), and `O:`
/// (origin → genre). When a user pastes or edits ABC we use these to
/// auto-populate the matching tune fields, so they don't have to re-enter what
/// the notation already states. Any field we can't confidently map is left
/// null.
class AbcMetadata {
  const AbcMetadata({this.type, this.composer, this.genre});

  /// Tune type parsed from the `R:` (rhythm) field, or null if absent/unknown.
  final TuneType? type;

  /// Composer parsed from the `C:` field, or null when absent or when the value
  /// denotes "no composer" (e.g. "Trad.", "Anon.").
  final String? composer;

  /// Genre parsed from the `O:` (origin) field, or null if absent/unknown.
  final String? genre;

  bool get isEmpty => type == null && composer == null && genre == null;
}

/// Parses [abc] header fields and returns any metadata that can be mapped to
/// the app's tune fields. See [AbcMetadata].
AbcMetadata parseAbcMetadata(String abc) {
  return AbcMetadata(
    type: _typeFromRhythm(_field(abc, 'R')),
    composer: _composerFromField(_field(abc, 'C')),
    genre: _genreFromOrigin(_field(abc, 'O')),
  );
}

/// Returns the first value of an ABC header field `tag:` (e.g. `R`, `C`, `O`),
/// trimmed, or null if the field is absent or empty.
String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  final value = match?.group(1)?.trim();
  return (value == null || value.isEmpty) ? null : value;
}

/// Maps an ABC `R:` rhythm value to a [TuneType]. Lenient about spacing,
/// punctuation, casing, and a few common spellings/separators.
TuneType? _typeFromRhythm(String? rhythm) {
  if (rhythm == null) return null;
  // Normalize: lowercase, drop trailing plural/punctuation, collapse separators.
  final r = rhythm
      .toLowerCase()
      .replaceAll(RegExp('[._]'), '')
      .replaceAll(RegExp(r'[\s-]+'), ' ')
      .trim();
  switch (r) {
    case 'reel':
    case 'reels':
      return TuneType.reel;
    case 'jig':
    case 'jigs':
    case 'double jig':
      return TuneType.jig;
    case 'hornpipe':
    case 'hornpipes':
      return TuneType.hornpipe;
    case 'polka':
    case 'polkas':
      return TuneType.polka;
    case 'slide':
    case 'slides':
      return TuneType.slide;
    case 'march':
    case 'marches':
      return TuneType.march;
    case 'slip jig':
    case 'slipjig':
    case 'hop jig':
      return TuneType.slipJig;
    case 'barndance':
    case 'barn dance':
      return TuneType.barndance;
    case 'waltz':
    case 'waltzes':
      return TuneType.waltz;
    case 'strathspey':
    case 'strathspeys':
      return TuneType.strathspey;
    case 'three two':
    case 'threetwo':
    case '3/2':
    case '3 2 hornpipe':
      return TuneType.threeTwo;
    case 'mazurka':
    case 'mazurkas':
      return TuneType.mazurka;
    default:
      return null;
  }
}

/// Returns a composer name from an ABC `C:` value, or null when the value
/// denotes a traditional/anonymous tune (no royalty attribution).
String? _composerFromField(String? composer) {
  if (composer == null) return null;
  final normalized = composer
      .toLowerCase()
      .replaceAll(RegExp(r'[.\s]'), '');
  const noComposer = {'trad', 'traditional', 'anon', 'anonymous', 'unknown'};
  if (noComposer.contains(normalized)) return null;
  return composer;
}

/// Maps an ABC `O:` origin value to one of [kTuneGenres]. The `O:` field is
/// free text — values range from a bare adjective ("Irish") to a place name
/// ("Shetland") to a phrase ("The Shetland Islands", "Co. Clare, Ireland") — so
/// we look for a known place/adjective keyword appearing as a whole word
/// anywhere in the value, preferring the longest (most specific) match so e.g.
/// "Cape Breton" wins over a stray "Breton" and "New England" over "England".
String? _genreFromOrigin(String? origin) {
  if (origin == null) return null;
  final o = origin.toLowerCase();

  // Keyword → genre. Includes each canonical genre as its own keyword (so
  // "Irish"/"Shetland" match directly) plus place names that imply a genre.
  final keywords = <String, String>{
    for (final genre in kTuneGenres) genre.toLowerCase(): genre,
    'ireland': 'Irish',
    'eire': 'Irish',
    'scotland': 'Scottish',
    'shetland islands': 'Shetland',
    'england': 'English',
    'wales': 'Welsh',
    'cymru': 'Welsh',
    'sweden': 'Swedish',
    'denmark': 'Danish',
    'norway': 'Norwegian',
    'finland': 'Finnish',
    'canada': 'French-Canadian',
    'quebec': 'Quebecois',
    'québec': 'Quebecois',
    // Brittany (France) vs Cape Breton (Nova Scotia) — distinct traditions that
    // share the word "Breton". Longest-keyword-first matching ensures a "Cape
    // Breton" origin never falls through to the bare "breton" → Breton entry.
    'brittany': 'Breton',
    'bretagne': 'Breton',
    'cape breton island': 'Cape Breton',
    'usa': 'American',
    'united states': 'American',
    'america': 'American',
    'texas': 'Texas',
    'new england': 'New England',
  };

  // Longest keyword first so more specific phrases take precedence.
  final ordered = keywords.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final keyword in ordered) {
    if (RegExp('\\b${RegExp.escape(keyword)}\\b').hasMatch(o)) {
      return keywords[keyword];
    }
  }
  return null;
}
