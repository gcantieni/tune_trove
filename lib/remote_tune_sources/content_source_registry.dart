import 'package:http/http.dart' as http;
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/static_asset_source.dart';
import 'package:tune_trove/remote_tune_sources/thesession_live_source.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';

/// Master registry of every content source the app knows about.
///
/// Sources with [ContentSourceMeta.confirmationRequired] == false are active
/// on first launch with no user action required (CC0 / public domain).
/// All others are inactive until the user explicitly confirms their license.
const List<ContentSourceMeta> allContentSources = [
  ContentSourceMeta(
    id: 'oneills_1001',
    name: "O'Neill's 1001",
    license: 'Public Domain',
    attribution:
        "O'Neill's 1001 Gems — compiled by Francis O'Neill (1907). Traditional Irish folk tunes; public domain.",
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'williamclarke',
    name: 'William Clarke of Feltwell',
    license: 'Public Domain',
    attribution:
        'William Clarke of Feltwell tune manuscript (~1701). Traditional tunes; public domain.',
    confirmationRequired: false,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'thesession',
    name: 'thesession.org',
    license: 'CC BY-NC-SA 3.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-nc-sa/3.0/',
    attribution: 'The Session (thesession.org) — CC BY-NC-SA 3.0',
    confirmationRequired: true,
  ),
  ContentSourceMeta(
    id: 'norbeck',
    name: 'Norbeck',
    license: 'Free for personal non-commercial use',
    licenseUrl: 'https://www.norbeck.nu/abc/',
    attribution:
        "Henrik Norbeck's ABC Tune Collection — free for personal, non-commercial use only.",
    confirmationRequired: true,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'paulhardy',
    name: 'Paul Hardy Session Tunebook',
    license: 'CC BY-NC-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-nc-sa/4.0/',
    attribution: 'Paul Hardy Session Tunebook by Paul Hardy — CC BY-NC-SA 4.0.',
    confirmationRequired: true,
    bundled: true,
  ),
  ContentSourceMeta(
    id: 'pete_mac',
    name: 'Pete Mac Tunebook',
    license: 'CC0',
    licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
    attribution: "Pete Mac's Tunebook — CC0 (public domain).",
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
TuneSource buildTuneSource(ContentSourceMeta meta, {http.Client? client}) {
  switch (meta.id) {
    case 'thesession':
      return TheSessionTuneSource(client: client);
    case 'oneills_1001':
      return StaticAssetTuneSource(
        name: meta.name,
        assetPath: 'assets/data/oneills_tunes.json',
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
    default:
      throw ArgumentError('Unknown content source id: ${meta.id}');
  }
}
