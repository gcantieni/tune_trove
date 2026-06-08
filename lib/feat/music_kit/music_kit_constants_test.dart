import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/music_kit/music_kit_constants.dart';

void main() {
  group('catalogIdFromUrl', () {
    test('extracts the id after the catalog scheme', () {
      expect(
        catalogIdFromUrl('$kAppleMusicCatalogScheme:123456'),
        equals('123456'),
      );
    });

    test('returns the empty string when there is no id', () {
      expect(catalogIdFromUrl('$kAppleMusicCatalogScheme:'), equals(''));
    });

    test('returns null for a different scheme', () {
      expect(catalogIdFromUrl('https://music.apple.com/song/1'), isNull);
    });

    test('returns null for a bare id with no scheme', () {
      expect(catalogIdFromUrl('123456'), isNull);
    });

    test('returns null for the empty string', () {
      expect(catalogIdFromUrl(''), isNull);
    });

    test('preserves the full remainder including extra colons', () {
      expect(catalogIdFromUrl('$kAppleMusicCatalogScheme:a:b'), equals('a:b'));
    });
  });
}
