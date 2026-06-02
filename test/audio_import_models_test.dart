import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_import/audio_import_models.dart';

void main() {
  group('SharedAudioFile.fromMap', () {
    test('parses path and name (file transport)', () {
      final file = SharedAudioFile.fromMap({
        'path': '/tmp/a.m4a',
        'name': 'a.m4a',
      });
      expect(file, isNotNull);
      expect(file!.path, '/tmp/a.m4a');
      expect(file.url, isNull);
      expect(file.isUrl, isFalse);
      expect(file.name, 'a.m4a');
    });

    test('derives name from path when name missing', () {
      final file = SharedAudioFile.fromMap({'path': '/tmp/song.m4a'});
      expect(file!.name, 'song.m4a');
    });

    test('parses url and name (url transport)', () {
      final file = SharedAudioFile.fromMap({
        'url': 'https://music.apple.com/us/album/foo/1?i=2',
        'name': 'A song',
      });
      expect(file, isNotNull);
      expect(file!.url, 'https://music.apple.com/us/album/foo/1?i=2');
      expect(file.path, isNull);
      expect(file.isUrl, isTrue);
      expect(file.name, 'A song');
    });

    test('derives name from url when name missing', () {
      final file = SharedAudioFile.fromMap({
        'url': 'https://music.apple.com/us/song/x/9',
      });
      expect(file!.name, 'https://music.apple.com/us/song/x/9');
    });

    test('url takes precedence when both present', () {
      final file = SharedAudioFile.fromMap({
        'url': 'https://music.apple.com/us/song/x/9',
        'path': '/tmp/a.m4a',
      });
      expect(file!.isUrl, isTrue);
    });

    test('parses performers and autosave (share-sheet form)', () {
      final file = SharedAudioFile.fromMap({
        'path': '/tmp/a.m4a',
        'name': 'Practice session',
        'performers': 'The Band',
        'autosave': true,
      });
      expect(file, isNotNull);
      expect(file!.name, 'Practice session');
      expect(file.performers, 'The Band');
      expect(file.autosave, isTrue);
    });

    test('defaults performers null and autosave false when absent', () {
      final file = SharedAudioFile.fromMap({'path': '/tmp/a.m4a'});
      expect(file!.performers, isNull);
      expect(file.autosave, isFalse);
    });

    test('ignores empty performers', () {
      final file = SharedAudioFile.fromMap({
        'path': '/tmp/a.m4a',
        'performers': '',
      });
      expect(file!.performers, isNull);
    });

    test('url transport ignores performers/autosave', () {
      final file = SharedAudioFile.fromMap({
        'url': 'https://music.apple.com/us/song/x/9',
        'performers': 'ignored',
        'autosave': true,
      });
      expect(file!.isUrl, isTrue);
      expect(file.performers, isNull);
      expect(file.autosave, isFalse);
    });

    test('returns null when neither path nor url present', () {
      expect(SharedAudioFile.fromMap({}), isNull);
      expect(SharedAudioFile.fromMap({'path': ''}), isNull);
      expect(SharedAudioFile.fromMap({'url': ''}), isNull);
    });
  });
}
