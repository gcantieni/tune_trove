import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/music_kit/apple_music_link.dart';

void main() {
  group('appleMusicCatalogIdFromShareUrl', () {
    const cases = <String, String?>{
      // Album-track share form: the song id is the `i` query param.
      'https://music.apple.com/us/album/cold-blow/123456?i=789012': '789012',
      'https://music.apple.com/gb/album/the-chieftains-2/111?i=222': '222',
      // Song form: id is the last path segment, with or without country code.
      'https://music.apple.com/us/song/the-morning-dew/789012': '789012',
      'https://music.apple.com/song/the-morning-dew/789012': '789012',
      // Query noise / fragments are ignored.
      'https://music.apple.com/jp/album/foo/1?i=2&l=en&ls=1': '2',
      'https://music.apple.com/us/album/foo/1?i=2#t=30': '2',
      // Album page with no `?i=` is not a single song.
      'https://music.apple.com/us/album/cold-blow/123456': null,
      // Non-song resources.
      'https://music.apple.com/us/playlist/foo/pl.123': null,
      'https://music.apple.com/us/artist/planxty/333': null,
      // Non-Apple-Music hosts.
      'https://open.spotify.com/track/abc': null,
      'https://example.com/us/song/x/1': null,
      // Garbage.
      'not a url': null,
      '': null,
      // Case-insensitive host/scheme.
      'HTTPS://MUSIC.APPLE.COM/US/SONG/X/999': '999',
      // Alternate hosts.
      'https://beta.music.apple.com/us/song/x/999': '999',
      'https://geo.music.apple.com/us/album/x/1?i=2': '2',
    };

    cases.forEach((url, expected) {
      test('"$url" -> ${expected ?? "null"}', () {
        expect(appleMusicCatalogIdFromShareUrl(url), expected);
      });
    });
  });

  group('isAppleMusicShareUrl', () {
    const appleMusic = [
      'https://music.apple.com/us/album/foo/1?i=2',
      'https://music.apple.com/us/song/x/9',
      'https://music.apple.com/us/album/foo/1', // album, still AM
      'https://music.apple.com/us/playlist/foo/pl.1', // playlist, still AM
      'https://beta.music.apple.com/us/song/x/9',
    ];
    const notAppleMusic = [
      'https://open.spotify.com/track/abc',
      'https://example.com/x',
      'not a url',
      '',
    ];

    for (final url in appleMusic) {
      test('true for "$url"', () => expect(isAppleMusicShareUrl(url), isTrue));
    }
    for (final url in notAppleMusic) {
      test(
        'false for "$url"',
        () => expect(isAppleMusicShareUrl(url), isFalse),
      );
    }
  });

  group('appleMusicNameFromSlug', () {
    const cases = <String, String?>{
      'https://music.apple.com/us/song/the-morning-dew/1': 'The Morning Dew',
      'https://music.apple.com/us/album/cold-blow-and-the-rainy-night/1?i=2':
          'Cold Blow And The Rainy Night',
      'https://music.apple.com/song/x/9': 'X',
      'https://example.com/song/x/1': null,
      'not a url': null,
    };

    cases.forEach((url, expected) {
      test('"$url" -> ${expected ?? "null"}', () {
        expect(appleMusicNameFromSlug(url), expected);
      });
    });
  });
}
