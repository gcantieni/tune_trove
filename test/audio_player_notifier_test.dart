import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/audio_player_backend.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';
import 'package:tune_trove/feat/audio_player/local_file_backend.dart';

class _MockBackend implements AudioPlayerBackend {
  final _controller = StreamController<AudioPlayerState>.broadcast();
  String? lastPlayedUri;
  double? lastStartTime;

  @override
  Stream<AudioPlayerState> get stateStream => _controller.stream;

  @override
  Future<void> play(String trackUri, {double? startTime}) async {
    lastPlayedUri = trackUri;
    lastStartTime = startTime;
    _controller.add(
      AudioPlayerState(
        trackUri: trackUri,
        status: AudioPlaybackStatus.playing,
        position: startTime ?? 0,
        duration: 120,
      ),
    );
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(double positionSeconds) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  void dispose() => _controller.close();
}

void main() {
  group('AudioPlayerNotifier.playWithBounds', () {
    late _MockBackend backend;
    late ProviderContainer container;

    setUp(() {
      backend = _MockBackend();
      container = ProviderContainer(
        overrides: [localFileBackendProvider.overrideWithValue(backend)],
      );
    });

    tearDown(() {
      container.dispose();
      backend.dispose();
    });

    test('with both start and end enables loop at those bounds', () async {
      final notifier = container.read(audioPlayerProvider.notifier);
      await notifier.playWithBounds(
        'app-data:test.mp3',
        start: 10.0,
        end: 60.0,
      );

      final s = container.read(audioPlayerProvider);
      expect(s.isLooping, isTrue);
      expect(s.loopStart, 10.0);
      expect(s.loopEnd, 60.0);
      expect(backend.lastStartTime, 10.0);
    });

    test('with start only seeks but does not enable loop', () async {
      final notifier = container.read(audioPlayerProvider.notifier);
      await notifier.playWithBounds(
        'app-data:test.mp3',
        start: 30.0,
        end: null,
      );

      final s = container.read(audioPlayerProvider);
      expect(s.isLooping, isFalse);
      expect(backend.lastStartTime, 30.0);
    });

    test('with neither start nor end plays from beginning without loop',
        () async {
      final notifier = container.read(audioPlayerProvider.notifier);
      await notifier.playWithBounds(
        'app-data:test.mp3',
        start: null,
        end: null,
      );

      final s = container.read(audioPlayerProvider);
      expect(s.isLooping, isFalse);
      expect(backend.lastStartTime, isNull);
    });

    test('loop state is preserved through the backend state update', () async {
      final notifier = container.read(audioPlayerProvider.notifier);
      await notifier.playWithBounds(
        'app-data:test.mp3',
        start: 15.0,
        end: 45.0,
      );

      // State emitted by backend is merged with notifier loop state.
      final s = container.read(audioPlayerProvider);
      expect(s.trackUri, 'app-data:test.mp3');
      expect(s.isPlaying, isTrue);
      expect(s.isLooping, isTrue);
      expect(s.loopStart, 15.0);
      expect(s.loopEnd, 45.0);
    });
  });
}
