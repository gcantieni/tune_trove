import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';

void main() {
  group('AudioPlayerState status getters', () {
    test('default state is stopped', () {
      const s = AudioPlayerState();
      expect(s.isStopped, isTrue);
      expect(s.isPlaying, isFalse);
      expect(s.isPaused, isFalse);
    });

    test('isPlaying only for playing status', () {
      const s = AudioPlayerState(status: AudioPlaybackStatus.playing);
      expect(s.isPlaying, isTrue);
      expect(s.isPaused, isFalse);
      expect(s.isStopped, isFalse);
    });

    test('isPaused only for paused status', () {
      const s = AudioPlayerState(status: AudioPlaybackStatus.paused);
      expect(s.isPaused, isTrue);
      expect(s.isPlaying, isFalse);
    });

    test('loading and error are neither playing, paused, nor stopped', () {
      const loading = AudioPlayerState(status: AudioPlaybackStatus.loading);
      const error = AudioPlayerState(status: AudioPlaybackStatus.error);
      for (final s in [loading, error]) {
        expect(s.isPlaying, isFalse);
        expect(s.isPaused, isFalse);
        expect(s.isStopped, isFalse);
      }
    });
  });

  group('AudioPlayerState.copyWith', () {
    const base = AudioPlayerState(
      trackUri: 'file:///a.m4a',
      status: AudioPlaybackStatus.playing,
      position: 5,
      duration: 100,
      playbackRate: 1.5,
      isLooping: true,
      loopStart: 1,
      loopEnd: 2,
      title: 'Reel',
      subtitle: 'Trad',
    );

    test('preserves trackUri (copyWith cannot change it)', () {
      final next = base.copyWith(status: AudioPlaybackStatus.paused);
      expect(next.trackUri, equals('file:///a.m4a'));
    });

    test('overrides only the provided fields', () {
      final next = base.copyWith(position: 42, playbackRate: 2.0);
      expect(next.position, equals(42));
      expect(next.playbackRate, equals(2.0));
      // Unchanged fields carry over.
      expect(next.status, equals(AudioPlaybackStatus.playing));
      expect(next.duration, equals(100));
      expect(next.isLooping, isTrue);
      expect(next.loopStart, equals(1));
      expect(next.loopEnd, equals(2));
      expect(next.title, equals('Reel'));
      expect(next.subtitle, equals('Trad'));
    });

    test('no arguments returns an equivalent state', () {
      final next = base.copyWith();
      expect(next.trackUri, base.trackUri);
      expect(next.status, base.status);
      expect(next.position, base.position);
      expect(next.duration, base.duration);
      expect(next.playbackRate, base.playbackRate);
      expect(next.isLooping, base.isLooping);
      expect(next.loopStart, base.loopStart);
      expect(next.loopEnd, base.loopEnd);
      expect(next.title, base.title);
      expect(next.subtitle, base.subtitle);
    });
  });
}
