import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/static_asset_source.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';

/// Master registry of every content source the app knows about.
///
/// Sources with [ContentSourceMeta.confirmationRequired] == false are active
/// on first launch with no user action required (CC0 / public domain), but
/// the user may disable any of them. All others are inactive until the user
/// explicitly confirms their license.
const List<ContentSourceMeta> allContentSources = [
  ContentSourceMeta(
    id: 'oneills_1001',
    name: "O'Neill's 1001",
    genre: 'Irish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        "O'Neill's 1001 Gems — compiled by Francis O'Neill (1907). Traditional Irish folk tunes. "
        "Transcription copyrighted 1997-2000 by the contributors to the O'Neill's Project. "
        "Courtesy of John Chambers.",
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'oneills_1850',
    name: "O'Neill's 1850",
    genre: 'Irish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        "O'Neill's Music of Ireland: Eighteen Hundred and Fifty Melodies — "
        "compiled by Capt. Francis O'Neill (1903). "
        "Transcription copyrighted 1997-2000 by the contributors to the O'Neill's Project. "
        'Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'williamclarke',
    name: 'William Clarke of Feltwell',
    genre: 'English',
    license: 'Public Domain',
    attribution:
        'William Clarke of Feltwell tune manuscript (~1701). Traditional tunes; public domain. '
        'Transcription by Lyn Law, David Dolby, Anahata and Mary Humphreys.',
    confirmationRequired: false,
  ),
  ContentSourceMeta(
    id: 'thesession',
    name: 'thesession.org',
    genre: '',
    license: 'ODbL 1.0',
    licenseUrl: 'https://opendatacommons.org/licenses/odbl/1-0/',
    attribution:
        'Contains information from The Session, which is made available '
        'here under the Open Database License (ODbL).',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'norbeck',
    name: 'Norbeck',
    genre: '',
    license: 'Free for personal non-commercial use',
    licenseUrl: 'https://www.norbeck.nu/abc/',
    attribution:
        "Henrik Norbeck's ABC Tune Collection — free for personal, non-commercial use only.",
    confirmationRequired: true,
    bundled: true,
    hidden: true,
  ),
  ContentSourceMeta(
    id: 'paulhardy',
    name: 'Paul Hardy Session Tunebook',
    genre: '',
    license: 'CC BY-NC-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
    attribution: 'Paul Hardy Session Tunebook by Paul Hardy — CC BY-NC-SA 4.0.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'pete_mac',
    name: 'Pete Mac Tunebook',
    genre: 'Irish',
    license: 'CC0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: "Pete Mac's Tunebook — CC0 (public domain).",
    confirmationRequired: false,
  ),
  ContentSourceMeta(
    id: 'athole',
    name: 'The Athole Collection (1884)',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        'The Athole Collection, compiled by James Stewart-Robertson '
        '(Edinburgh, 1884). Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'bremner',
    name: "Bremner's Scots Reels (1757)",
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"A Collection of Scots Reels or Country Dances", published by Robert '
        'Bremner (London, 1757). ABC transcriptions by John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'aird',
    name:
        'The James Aird Collection, Vol. 1-6: A Selection of Scotch, English, Irish and Foreign Airs',
    genre: '',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        'The James Aird Collection, Vol. 1-6 (Glasgow, 1778–1782). '
        'ABC transcriptions by Jack Campin (1999). Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'neil_gow',
    name: 'Neil Gow & Sons Complete Repository (1799–1839)',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        'Niel Gow & Sons Complete Repository of Original Scots Slow Strathspeys and Dances '
        '(Edinburgh, 1799–1839). ABC transcriptions by John Chambers (2021). '
        'Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'fraser',
    name:
        'Fraser Collection — Airs and Melodies Peculiar to the Highlands and The Isles',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"Airs and Melodies Peculiar to the Highlands and The Isles" '
        'by Captain Simon Fraser (Edinburgh, 1816). Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'erm',
    name: 'Edinburgh Repository of Music',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        'Edinburgh Repository of Music, J. Sutherland, Edinburgh, 1815–1825. '
        'Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'nefr',
    name: "New England Fiddler's Repertoire",
    genre: 'New England',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        "New England Fiddler's Repertoire, compiled by Randy Miller and Jack Perron. "
        'Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'kidson',
    name: 'Old English Country Dances',
    genre: 'English',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"Old English Country Dances", collected and edited by Frank Kidson, '
        'William Reeves, London, 1890. Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'nelson',
    name: 'The Nelson Music Collection',
    genre: 'New England',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"Selected Authentic Square Dance Melodies" (1969), '
        'compiled by Newton F. Tolman and K. Dep. Gilbert. '
        'Transcribed to ABC by Ralph Palmer. Courtesy of John Chambers.',
    confirmationRequired: true,
    bundled: true,
    hidden: true,
  ),
  ContentSourceMeta(
    id: 'meikle',
    name: 'Originally Mine',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"Originally Mine" by George Meikle. Courtesy of John Chambers.',
    confirmationRequired: true,
    bundled: true,
    hidden: true,
  ),
  ContentSourceMeta(
    id: 'mulhollan',
    name: 'The John Macpherson Mulhollan Collection',
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        '"Airs and Melodies Peculiar to the Highlands and The Isles" '
        'by John Macpherson Mulhollan (1814). Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'ryans_mammoth',
    name: "Ryan's Mammoth Collection",
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        "Ryan's Mammoth Collection of Fiddle Tunes, ed. William Bradbury Ryan "
        '(Boston, 1884); republished as "1000 Fiddle Tunes" by Cole Publishing '
        'Company (1940). Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'pringle',
    name: "John Pringle's Collection",
    genre: 'Scottish',
    license: 'GNU GPL',
    licenseUrl: 'https://www.gnu.org/licenses/gpl-3.0.html',
    attribution:
        "John Pringle's Collection of Reels Strathspey & Jigs (1801). "
        'Courtesy of John Chambers.',
    confirmationRequired: true,
  ),
];

/// Returns true when a tune whose [Tune.from] equals [sourceName] is permitted
/// to display given the currently [activeSourceNames].
///
/// Rules:
///   - null / empty → always visible (user-created tune with no source)
///   - matches a registry source that is active → visible
///   - matches a registry source that is inactive → hidden
///   - matches nothing in the registry (user-typed free text) → always visible
/// Genres shown first in the Content Library, in market-priority order.
/// Anything outside this list sorts after, by genre name; ungenred sources
/// sort last.
const _genreDisplayPriority = ['Irish', 'Scottish', 'English'];

int _genreRank(String genre) {
  final i = _genreDisplayPriority.indexOf(genre);
  if (i != -1) return i;
  if (genre.isEmpty) return 1000; // ungenred sources go last
  return 100; // other genres (e.g. New England) sit in between
}

/// thesession.org is the broad catch-all aggregator; it always sorts last so
/// the curated, genre-specific collections surface first.
const _alwaysLastSourceId = 'thesession';

/// Sort key for a source name that ignores a leading "The " so, e.g., "The
/// Athole Collection" alphabetizes under A rather than T.
String _nameSortKey(String name) {
  final match = RegExp(r'^the\s+', caseSensitive: false).firstMatch(name);
  return (match == null ? name : name.substring(match.end)).trim();
}

/// Orders content sources for display: by market-priority genre
/// (Irish → Scottish → English), then remaining genres alphabetically, then
/// ungenred sources, breaking ties by source name. thesession.org is always
/// pinned last regardless of genre.
int compareSourcesForDisplay(ContentSourceMeta a, ContentSourceMeta b) {
  final aLast = a.id == _alwaysLastSourceId;
  final bLast = b.id == _alwaysLastSourceId;
  if (aLast != bLast) return aLast ? 1 : -1;

  final rankDelta = _genreRank(a.genre).compareTo(_genreRank(b.genre));
  if (rankDelta != 0) return rankDelta;
  final genreDelta = a.genre.compareTo(b.genre);
  if (genreDelta != 0) return genreDelta;
  return _nameSortKey(a.name).compareTo(_nameSortKey(b.name));
}

bool isSourceNameVisible(String? sourceName, Set<String> activeSourceNames) {
  if (sourceName == null || sourceName.isEmpty) return true;
  final inRegistry = allContentSources.any((m) => m.name == sourceName);
  if (!inRegistry) return true;
  return activeSourceNames.contains(sourceName);
}

/// Instantiates the [TuneSource] implementation for the given [meta].
TuneSource buildTuneSource(ContentSourceMeta meta) {
  switch (meta.id) {
    case 'thesession':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/thesession_tunes.json',
      );
    case 'oneills_1001':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/oneills_1001_tunes.json',
      );
    case 'oneills_1850':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/oneills_1850_tunes.json',
      );
    case 'norbeck':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/norbeck_tunes.json',
      );
    case 'williamclarke':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/williamclarke_tunes.json',
      );
    case 'paulhardy':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/paulhardy_tunes.json',
      );
    case 'pete_mac':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/pete_mac_tunes.json',
      );
    case 'athole':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/athole_tunes.json',
      );
    case 'bremner':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/bremner_tunes.json',
      );
    case 'aird':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/aird_tunes.json',
      );
    case 'neil_gow':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/neil_gow_tunes.json',
      );
    case 'fraser':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/fraser_tunes.json',
      );
    case 'erm':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/erm_tunes.json',
      );
    case 'nefr':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/nefr_tunes.json',
      );
    case 'kidson':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/kidson_tunes.json',
      );
    case 'nelson':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/nelson_tunes.json',
      );
    case 'meikle':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/meikle_tunes.json',
      );
    case 'mulhollan':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/mulhollan_tunes.json',
      );
    case 'ryans_mammoth':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/ryans_mammoth_tunes.json',
      );
    case 'pringle':
      return StaticAssetTuneSource(
        name: meta.name,
        defaultGenre: meta.genre,
        assetPath: 'assets/data/pringle_tunes.json',
      );
    default:
      throw ArgumentError('Unknown content source id: ${meta.id}');
  }
}
