// Parsing helpers for Apple Music share links (`https://music.apple.com/...`),
// the inverse of the in-app MusicKit search: a link shared *from* Apple Music is
// turned into a `music-catalog:<id>` recording. Pure; no I/O.

const _appleMusicHostSuffix = 'music.apple.com';

/// Extracts the Apple Music *song* catalog id from a `music.apple.com` share URL,
/// or null for anything that isn't a link we can resolve to a single song.
///
/// Handles the album-track form (`…/album/<slug>/<albumId>?i=<songId>` → the `i`
/// param) and the song form (`…/[cc/]song/<slug>/<songId>` → the last path
/// segment). The optional country-code segment is located by the `album`/`song`
/// keyword rather than a fixed index. A bare album link (no `?i=`) is an album,
/// not a song, so it returns null — as do playlists, artists, and non-Apple-Music
/// hosts.
String? appleMusicCatalogIdFromShareUrl(String raw) {
  final uri = _appleMusicUri(raw);
  if (uri == null) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  // Path segments keep their original case; match the keyword case-insensitively.
  final lower = segments.map((s) => s.toLowerCase()).toList();
  if (lower.contains('song')) {
    // …/song/<slug>/<id> — id is the last segment after the `song` keyword.
    final i = lower.indexOf('song');
    if (i + 2 < segments.length) return segments[i + 2];
    return null;
  }
  if (lower.contains('album')) {
    // Album page; only a specific track (`?i=`) counts as a song.
    final songId = uri.queryParameters['i'];
    if (songId != null && songId.isNotEmpty) return songId;
    return null;
  }
  return null;
}

/// Whether [raw] is a recognizable Apple Music web link (any resource — song,
/// album, playlist, artist). Used to gate transport and the "Add from link" UI.
bool isAppleMusicShareUrl(String raw) => _appleMusicUri(raw) != null;

/// The public Apple Music *web* URL for a song catalog id. Recordings imported
/// from an Apple Music link are stored under the internal `music-catalog:<id>`
/// scheme, which no app can open directly ("There is no application set to open
/// the URL music-catalog:…"). This rebuilds an openable link: the storefront-
/// less `…/song/<id>` form is geo-redirected by Apple Music to the visitor's
/// storefront/slugged title, and opens the Apple Music app when installed.
String appleMusicWebUrlForCatalogId(String catalogId) =>
    'https://music.apple.com/song/$catalogId';

/// Derives a human title from an Apple Music link's slug, for use as a fallback
/// recording name when catalog metadata can't be resolved (MusicKit unavailable
/// / unauthorized). `…/song/the-morning-dew/1` → `The Morning Dew`. Returns null
/// for non-Apple-Music links or when no slug is present.
String? appleMusicNameFromSlug(String raw) {
  final uri = _appleMusicUri(raw);
  if (uri == null) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final lower = segments.map((s) => s.toLowerCase()).toList();
  for (final keyword in const ['song', 'album']) {
    final i = lower.indexOf(keyword);
    if (i >= 0 && i + 1 < segments.length) {
      final slug = segments[i + 1];
      final words = slug
          .split('-')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}');
      final name = words.join(' ');
      if (name.isNotEmpty) return name;
    }
  }
  return null;
}

/// Parses [raw] and returns its [Uri] iff it's a valid http(s) Apple Music link,
/// else null. Centralizes host matching (case-insensitive, allows `beta.`/`geo.`
/// subdomains) so every helper agrees on what counts as Apple Music.
Uri? _appleMusicUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host == _appleMusicHostSuffix ||
      host.endsWith('.$_appleMusicHostSuffix')) {
    return uri;
  }
  return null;
}
