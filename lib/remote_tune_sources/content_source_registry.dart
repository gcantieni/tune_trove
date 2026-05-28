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
        "O'Neill's 1001 Gems — compiled by Francis O'Neill (1907). Traditional Irish folk tunes. " +
        "Transcription copyrighted 1997-2000 by the contributors to the O'Neill's Project. " +
        "Courtesy of John Chambers.",
    confirmationRequired: true,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'williamclarke',
    name: 'William Clarke of Feltwell',
    genre: 'English',
    license: 'Public Domain',
    attribution:
        'William Clarke of Feltwell tune manuscript (~1701). Traditional tunes; public domain.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'thesession',
    name: 'thesession.org',
    genre: 'Irish / Celtic',
    license: 'ODbL 1.0',
    licenseUrl: 'https://opendatacommons.org/licenses/odbl/1-0/',
    attribution:
        'Contains information from The Session, which is made available '
        'here under the Open Database License (ODbL).',
    confirmationRequired: true,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'norbeck',
    name: 'Norbeck',
    genre: 'Irish / Celtic',
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
    genre: 'British Isles',
    license: 'CC BY-NC-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
    attribution: 'Paul Hardy Session Tunebook by Paul Hardy — CC BY-NC-SA 4.0.',
    confirmationRequired: true,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'pete_mac',
    name: 'Pete Mac Tunebook',
    genre: 'Irish',
    license: 'CC0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: "Pete Mac's Tunebook — CC0 (public domain).",
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'athole',
    name: 'The Athole Collection (1884)',
    genre: 'Scottish',
    license: 'Public Domain',
    attribution:
        'The Athole Collection, compiled by James Stewart-Robertson '
        '(Edinburgh, 1884). Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'aird',
    name:
        'The James Aird Collection, Vol. 1-6: A Selection of Scotch, English, Irish and Foreign Airs',
    genre: 'Scottish, English & Irish',
    license: 'Public Domain',
    attribution:
        'The James Aird Collection, Vol. 1-6 (Glasgow, 1778–1782). '
        'ABC transcriptions by Jack Campin (1999). Public domain. '
        'Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'neil_gow',
    name: 'Neil Gow & Sons Complete Repository (1799–1839)',
    genre: 'Scottish',
    license: 'Public Domain',
    attribution:
        'Niel Gow & Sons Complete Repository of Original Scots Slow Strathspeys and Dances '
        '(Edinburgh, 1799–1839). ABC transcriptions by John Chambers (2021). '
        'Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'fraser',
    name:
        'Fraser Collection — Airs and Melodies Peculiar to the Highlands and The Isles',
    genre: 'Scottish (Highland)',
    license: 'Public Domain',
    attribution:
        '"Airs and Melodies Peculiar to the Highlands and The Isles" '
        'by Captain Simon Fraser (Edinburgh, 1816). Public domain. '
        'Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'erm',
    name: 'Edinburgh Repository of Music',
    genre: 'Scottish & English',
    license: 'Public Domain',
    attribution:
        'Edinburgh Repository of Music, J. Sutherland, Edinburgh, 1815–1825. '
        'Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'nefr',
    name: "New England Fiddler's Repertoire",
    genre: 'New England / Contra',
    license: 'Public Domain',
    attribution:
        "New England Fiddler's Repertoire, compiled by Randy Miller and Jack Perron. "
        'Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'kidson',
    name: 'Old English Country Dances',
    genre: 'English',
    license: 'Public Domain',
    attribution:
        '"Old English Country Dances", collected and edited by Frank Kidson, '
        'William Reeves, London, 1890. Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'nelson',
    name: 'The Nelson Music Collection',
    genre: 'American / Square Dance',
    license: 'Public Domain',
    attribution:
        '"Selected Authentic Square Dance Melodies" (1969), '
        'compiled by Newton F. Tolman and K. Dep. Gilbert. '
        'Transcribed to ABC by Ralph Palmer. Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
    hidden: true,
  ),
  ContentSourceMeta(
    id: 'meikle',
    name: 'Originally Mine',
    genre: 'Scottish',
    license: 'Public Domain',
    attribution:
        '"Originally Mine" by George Meikle. '
        'Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
    hidden: true,
  ),
  ContentSourceMeta(
    id: 'mulhollan',
    name: 'The John Macpherson Mulhollan Collection',
    genre: 'Scottish (Highland)',
    license: 'Public Domain',
    attribution:
        '"Airs and Melodies Peculiar to the Highlands and The Isles" '
        'by John Macpherson Mulhollan (1814). Public domain. Courtesy of John Chambers.',
    confirmationRequired: false,
    bundled: true,
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
        assetPath: 'assets/data/thesession_tunes.json',
      );
    case 'oneills_1001':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/oneills_1001_tunes.json',
      );
    case 'norbeck':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/norbeck_tunes.json',
      );
    case 'williamclarke':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/williamclarke_tunes.json',
      );
    case 'paulhardy':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/paulhardy_tunes.json',
      );
    case 'pete_mac':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/pete_mac_tunes.json',
      );
    case 'athole':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/athole_tunes.json',
      );
    case 'aird':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/aird_tunes.json',
      );
    case 'neil_gow':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/neil_gow_tunes.json',
      );
    case 'fraser':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/fraser_tunes.json',
      );
    case 'erm':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/erm_tunes.json',
      );
    case 'nefr':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/nefr_tunes.json',
      );
    case 'kidson':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/kidson_tunes.json',
      );
    case 'nelson':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/nelson_tunes.json',
      );
    case 'meikle':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/meikle_tunes.json',
      );
    case 'mulhollan':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/mulhollan_tunes.json',
      );
    default:
      throw ArgumentError('Unknown content source id: ${meta.id}');
  }
}
