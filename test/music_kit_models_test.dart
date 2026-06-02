import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/music_kit/music_kit_constants.dart';
import 'package:tune_trove/feat/music_kit/music_kit_models.dart';

void main() {
  group('MusicKitSearchResult.fromMap', () {
    test('reads all fields from a complete map', () {
      final r = MusicKitSearchResult.fromMap(const {
        'kind': 'song',
        'id': '42',
        'title': "Cooley's",
        'artistName': 'Planxty',
        'albumTitle': 'Cold Blow',
        'durationMs': 1234,
        'artworkUrl': 'https://example.com/a.jpg',
      });
      expect(r.kind, 'song');
      expect(r.id, '42');
      expect(r.title, "Cooley's");
      expect(r.artistName, 'Planxty');
      expect(r.albumTitle, 'Cold Blow');
      expect(r.durationMs, 1234);
      expect(r.artworkUrl, 'https://example.com/a.jpg');
    });

    test('falls back to defaults for a missing/empty map', () {
      final r = MusicKitSearchResult.fromMap(const {});
      expect(r.kind, '');
      expect(r.id, '');
      expect(r.title, '');
      expect(r.artistName, '');
      expect(r.albumTitle, '');
      expect(r.durationMs, 0);
      expect(r.artworkUrl, '');
    });

    test('toRecordingUrl prefixes the catalog scheme', () {
      const r = MusicKitSearchResult(
        kind: 'song',
        id: '99',
        title: '',
        artistName: '',
        albumTitle: '',
        durationMs: 0,
        artworkUrl: '',
      );
      expect(r.toRecordingUrl(), '$kAppleMusicCatalogScheme:99');
    });
  });

  group('MusicKitPlaybackState.fromMap', () {
    test('converts durationMs to seconds and reads position', () {
      final s = MusicKitPlaybackState.fromMap(const {
        'event': 'positionUpdate',
        'status': 'playing',
        'position': 12.5,
        'durationMs': 240000,
        'catalogId': '7',
        'title': 'The Morning Dew',
        'artistName': 'The Chieftains',
      });
      expect(s.event, 'positionUpdate');
      expect(s.status, 'playing');
      expect(s.position, 12.5);
      expect(s.duration, 240.0);
      expect(s.catalogId, '7');
      expect(s.title, 'The Morning Dew');
      expect(s.artistName, 'The Chieftains');
    });

    test('defaults status to unknown and numbers to zero', () {
      final s = MusicKitPlaybackState.fromMap(const {});
      expect(s.status, 'unknown');
      expect(s.position, 0.0);
      expect(s.duration, 0.0);
    });

    test('status getters reflect the current status', () {
      MusicKitPlaybackState withStatus(String status) =>
          MusicKitPlaybackState.fromMap({'status': status});
      expect(withStatus('playing').isPlaying, isTrue);
      expect(withStatus('paused').isPaused, isTrue);
      expect(withStatus('stopped').isStopped, isTrue);
      expect(withStatus('playing').isPaused, isFalse);
    });
  });

  group('MusicKitPlayParams.toMap', () {
    test('omits null start/end times', () {
      const p = MusicKitPlayParams(catalogId: '5');
      final map = p.toMap();
      expect(map['catalogId'], '5');
      expect(map.containsKey('startTime'), isFalse);
      expect(map.containsKey('endTime'), isFalse);
      expect(map['playbackRate'], 1.0);
      expect(map['loopCount'], 0);
    });

    test('includes start/end times when provided', () {
      const p = MusicKitPlayParams(
        catalogId: '5',
        startTime: 10.0,
        endTime: 20.0,
        playbackRate: 0.75,
        loopCount: -1,
      );
      final map = p.toMap();
      expect(map['startTime'], 10.0);
      expect(map['endTime'], 20.0);
      expect(map['playbackRate'], 0.75);
      expect(map['loopCount'], -1);
    });
  });
}
