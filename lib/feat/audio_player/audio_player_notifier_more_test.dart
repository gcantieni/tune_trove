import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/audio_player_backend.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';
import 'package:tune_trove/feat/audio_player/local_file_backend.dart';
import 'package:tune_trove/feat/music_kit/music_kit_backend.dart';

/// Records every transport call so we can assert delegation and loop behaviour.
class FakeBackend implements AudioPlayerBackend {
  final _c = StreamController<AudioPlayerState>.broadcast();
  final plays = <({String uri, double? start})>[];
  final seeks = <double>[];
  final rates = <double>[];
  int pauses = 0;
  int resumes = 0;
  int stops = 0;

  @override
  Stream<AudioPlayerState> get stateStream => _c.stream;

  @override
  Future<void> play(String trackUri, {double? startTime}) async =>
      plays.add((uri: trackUri, start: startTime));

  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> seek(double positionSeconds) async => seeks.add(positionSeconds);
  @override
  Future<void> setPlaybackRate(double rate) async => rates.add(rate);

  void emit(AudioPlayerState s) => _c.add(s);

  @override
  void dispose() => _c.close();
}

/// A stand-in for the Apple Music backend. Implementing [MusicKitBackend] is
/// enough here because only its public (AudioPlayerBackend) surface is used.
class FakeMusicBackend implements MusicKitBackend {
  final _c = StreamController<AudioPlayerState>.broadcast();
  final plays = <String>[];
  int stops = 0;

  @override
  Stream<AudioPlayerState> get stateStream => _c.stream;
  @override
  Future<void> play(String trackUri, {double? startTime}) async =>
      plays.add(trackUri);
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> seek(double positionSeconds) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  void dispose() => _c.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend local;
  late ProviderContainer container;

  setUp(() {
    local = FakeBackend();
    container = ProviderContainer(
      overrides: [localFileBackendProvider.overrideWithValue(local)],
    );
  });
  tearDown(() {
    container.dispose();
    local.dispose();
  });

  AudioPlayerNotifier notifier() =>
      container.read(audioPlayerProvider.notifier);
  AudioPlayerState state() => container.read(audioPlayerProvider);

  group('play + transport delegation', () {
    test(
      'play routes to the local backend with no startTime when not looping',
      () async {
        await notifier().play('app-data:a.mp3');
        expect(local.plays.single.uri, 'app-data:a.mp3');
        expect(local.plays.single.start, isNull);
      },
    );

    test('transport calls before play are no-ops', () async {
      // No active backend yet: these must resolve without throwing.
      await notifier().pause();
      await notifier().resume();
      await notifier().stop();
      await notifier().seek(5);
      expect(local.pauses, 0);
      expect(local.seeks, isEmpty);
    });

    test('pause/resume/stop/seek delegate to the active backend', () async {
      final n = notifier();
      await n.play('app-data:a.mp3');
      await n.pause();
      await n.resume();
      await n.stop();
      await n.seek(12.5);
      expect(local.pauses, 1);
      expect(local.resumes, 1);
      expect(local.stops, 1);
      expect(local.seeks, [12.5]);
    });
  });

  group('playback rate', () {
    test(
      'updates state immediately and the backend after the debounce',
      () async {
        final n = notifier();
        await n.play('app-data:a.mp3');
        local.rates.clear(); // ignore the rate re-applied on play
        n.setPlaybackRate(0.75);
        expect(state().playbackRate, 0.75); // immediate
        expect(local.rates, isEmpty); // debounced
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(local.rates, [0.75]);
      },
    );

    test(
      'play re-applies the chosen speed (a reload resets it to 1x)',
      () async {
        final n = notifier();
        await n.play('app-data:a.mp3');
        n.setPlaybackRate(0.5);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        local.rates.clear();

        // Playing again (e.g. the big play button after stopping) must push the
        // chosen speed back to the backend, which a reload would otherwise drop.
        await n.play('app-data:a.mp3');
        expect(local.rates, contains(0.5));
      },
    );

    test('resume re-applies the chosen speed', () async {
      final n = notifier();
      await n.play('app-data:a.mp3');
      n.setPlaybackRate(0.5);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      local.rates.clear();

      await n.resume();
      expect(local.rates, contains(0.5));
    });
  });

  group('loop state across tracks', () {
    test('switching to a different track clears the previous loop', () async {
      final n = notifier();
      await n.playWithBounds('app-data:a.mp3', start: 10, end: 20);
      expect(state().isLooping, isTrue);

      await n.play('app-data:b.mp3'); // different recording
      expect(state().isLooping, isFalse);
      expect(state().loopStart, 0);
      expect(state().loopEnd, 0);
    });

    test('replaying the same track keeps its loop', () async {
      final n = notifier();
      await n.playWithBounds('app-data:a.mp3', start: 10, end: 20);
      // Simulate the track being the current one (backend echoes the uri).
      local.emit(
        const AudioPlayerState(
          trackUri: 'app-data:a.mp3',
          status: AudioPlaybackStatus.playing,
          duration: 120,
        ),
      );
      await pumpEventQueue();

      await n.play('app-data:a.mp3'); // same recording
      expect(state().isLooping, isTrue);
      expect(state().loopStart, 10);
      expect(state().loopEnd, 20);
    });
  });

  group('loop config', () {
    test(
      'toggleLoop falls back to a 60s loop end when duration is unknown',
      () {
        notifier().toggleLoop();
        expect(state().isLooping, isTrue);
        expect(state().loopEnd, 60.0);
      },
    );

    test('toggleLoop uses the known duration for the loop end', () async {
      final n = notifier();
      await n.play('app-data:a.mp3');
      local.emit(
        const AudioPlayerState(
          trackUri: 'app-data:a.mp3',
          status: AudioPlaybackStatus.playing,
          duration: 120,
        ),
      );
      await pumpEventQueue();
      n.toggleLoop();
      expect(state().loopEnd, 120.0);
    });

    test('toggleLoop twice disables looping', () {
      final n = notifier()..toggleLoop();
      expect(state().isLooping, isTrue);
      n.toggleLoop();
      expect(state().isLooping, isFalse);
    });

    test('setLoopBounds updates the bounds', () {
      notifier().setLoopBounds(3, 9);
      expect(state().loopStart, 3);
      expect(state().loopEnd, 9);
    });
  });

  group('loop enforcement', () {
    test('seeks back to loopStart when playback runs past loopEnd', () async {
      final n = notifier();
      await n.playWithBounds('app-data:a.mp3', start: 10, end: 20);
      local.emit(
        const AudioPlayerState(
          trackUri: 'app-data:a.mp3',
          status: AudioPlaybackStatus.playing,
          position: 25, // past loopEnd
          duration: 120,
        ),
      );
      await pumpEventQueue();
      expect(local.seeks, contains(10.0));
    });

    test('replays from loopStart when a looping track stops', () async {
      final n = notifier();
      await n.playWithBounds('app-data:a.mp3', start: 5, end: 15);
      expect(local.plays, hasLength(1));
      local.emit(
        // Default status is stopped — the track has finished playing.
        const AudioPlayerState(trackUri: 'app-data:a.mp3'),
      );
      await pumpEventQueue();
      expect(local.plays, hasLength(2));
      expect(local.plays.last.start, 5.0);
    });
  });

  group('per-recording memory', () {
    // The real backend echoes the active track URI in its state stream; the
    // fake doesn't, so simulate that ack so state.trackUri tracks switches.
    Future<void> ack(String uri) async {
      local.emit(
        AudioPlayerState(
          trackUri: uri,
          status: AudioPlaybackStatus.playing,
          duration: 120,
        ),
      );
      await pumpEventQueue();
    }

    Future<void> playAndAck(AudioPlayerNotifier n, String uri) async {
      await n.play(uri);
      await ack(uri);
    }

    test('each recording keeps its own loop across navigation', () async {
      final n = notifier();

      // Recording A gets a 10–20s loop.
      await n.playWithBounds('a.mp3', start: 10, end: 20);
      await ack('a.mp3');

      // Switch to B: starts fresh, no loop.
      await playAndAck(n, 'b.mp3');
      expect(state().isLooping, isFalse);

      // Navigate back to A: its loop is restored.
      await playAndAck(n, 'a.mp3');
      expect(state().isLooping, isTrue);
      expect(state().loopStart, 10);
      expect(state().loopEnd, 20);
    });

    test(
      'speed carries to a new recording but each remembers its own',
      () async {
        final n = notifier();
        await playAndAck(n, 'a.mp3');
        n.setPlaybackRate(0.5);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        // A new recording inherits the current speed (sticky).
        await playAndAck(n, 'b.mp3');
        expect(state().playbackRate, 0.5);
        n.setPlaybackRate(0.75);
        await Future<void>.delayed(const Duration(milliseconds: 120));

        // Back to A restores 0.5; forward to B restores 0.75.
        await playAndAck(n, 'a.mp3');
        expect(state().playbackRate, 0.5);
        await playAndAck(n, 'b.mp3');
        expect(state().playbackRate, 0.75);
      },
    );
  });

  group('cross-backend playback', () {
    test(
      'switching backends stops the previous one so they do not overlap',
      () async {
        final music = FakeMusicBackend();
        final c = ProviderContainer(
          overrides: [
            localFileBackendProvider.overrideWithValue(local),
            musicKitBackendProvider.overrideWithValue(music),
          ],
        );
        addTearDown(c.dispose);
        final n = c.read(audioPlayerProvider.notifier);

        // Start an Apple Music track...
        await n.play('music-catalog:123');
        expect(music.plays, isNotEmpty);
        expect(music.stops, 0);

        // ...then play a local file: the music backend must be stopped.
        await n.play('app-data:a.mp3');
        expect(music.stops, 1);
        expect(local.plays, isNotEmpty);

        // Back to Apple Music: the local backend is stopped in turn.
        await n.play('music-catalog:123');
        expect(local.stops, 1);
      },
    );
  });
}
