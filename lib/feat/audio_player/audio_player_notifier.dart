import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/audio_player/audio_player_backend.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';
import 'package:tune_trove/feat/audio_player/local_file_backend.dart';
import 'package:tune_trove/feat/music_kit/music_kit_backend.dart';

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  AudioPlayerBackend? _activeBackend;
  StreamSubscription<AudioPlayerState>? _backendSub;
  Timer? _rateDebounce;
  bool _seekPending = false;
  bool _playPending = false;

  @override
  AudioPlayerState build() {
    ref.onDispose(() {
      _backendSub?.cancel();
      _rateDebounce?.cancel();
    });
    return const AudioPlayerState();
  }

  AudioPlayerBackend _backendFor(String trackUri) {
    if (trackUri.startsWith('music-catalog:')) {
      return ref.read(musicKitBackendProvider);
    }
    return ref.read(localFileBackendProvider);
  }

  void _subscribeTo(AudioPlayerBackend backend) {
    _backendSub?.cancel();
    _activeBackend = backend;
    _backendSub = backend.stateStream.listen((backendState) {
      // Merge backend-reported fields with notifier-owned loop/rate config.
      final next = AudioPlayerState(
        trackUri: backendState.trackUri,
        status: backendState.status,
        position: backendState.position,
        duration: backendState.duration,
        title: backendState.title,
        subtitle: backendState.subtitle,
        playbackRate: state.playbackRate,
        isLooping: state.isLooping,
        loopStart: state.loopStart,
        loopEnd: state.loopEnd,
      );
      state = next;
      _enforceLoop(next);
    });
  }

  void _enforceLoop(AudioPlayerState s) {
    if (!s.isLooping || _seekPending) return;

    if (s.isStopped) {
      if (!_playPending && s.trackUri != null) _replayFromStart(s.trackUri!);
      return;
    }

    if (s.isPlaying && s.duration > 0) {
      if (s.position < s.loopStart || s.position >= s.loopEnd) {
        _seekPending = true;
        _activeBackend
            ?.seek(s.loopStart)
            .whenComplete(() => _seekPending = false);
      }
    }
  }

  Future<void> _replayFromStart(String trackUri) async {
    _playPending = true;
    try {
      final backend = _backendFor(trackUri);
      await backend.play(trackUri, startTime: state.loopStart);
      await _applyPlaybackRate(backend);
    } finally {
      _playPending = false;
    }
  }

  /// Re-applies the user's chosen speed to [backend]. Loading a track resets
  /// the underlying player to 1x, so the rate must be pushed back after every
  /// (re)start for the slider's value to be respected.
  Future<void> _applyPlaybackRate(AudioPlayerBackend backend) =>
      backend.setPlaybackRate(state.playbackRate);

  /// Clears any loop carried over from a previously-played track so its bounds
  /// don't bleed onto a different recording.
  void _clearLoopIfTrackChanged(String trackUri) {
    if (state.trackUri != trackUri) {
      state = state.copyWith(isLooping: false, loopStart: 0.0, loopEnd: 0.0);
    }
  }

  Future<void> play(String trackUri) async {
    final backend = _backendFor(trackUri);
    _clearLoopIfTrackChanged(trackUri);
    _subscribeTo(backend);
    await backend.play(
      trackUri,
      startTime: state.isLooping ? state.loopStart : null,
    );
    await _applyPlaybackRate(backend);
  }

  Future<void> playWithBounds(
    String trackUri, {
    required double? start,
    required double? end,
  }) async {
    final backend = _backendFor(trackUri);
    _subscribeTo(backend);
    if (start != null && end != null) {
      state = AudioPlayerState(
        trackUri: state.trackUri,
        status: state.status,
        position: state.position,
        duration: state.duration,
        title: state.title,
        subtitle: state.subtitle,
        playbackRate: state.playbackRate,
        isLooping: true,
        loopStart: start,
        loopEnd: end,
      );
      await backend.play(trackUri, startTime: start);
    } else {
      _clearLoopIfTrackChanged(trackUri);
      await backend.play(trackUri, startTime: start);
    }
    await _applyPlaybackRate(backend);
  }

  Future<void> pause() => _activeBackend?.pause() ?? Future.value();

  Future<void> resume() async {
    final backend = _activeBackend;
    if (backend == null) return;
    await backend.resume();
    await _applyPlaybackRate(backend);
  }

  Future<void> stop() => _activeBackend?.stop() ?? Future.value();

  Future<void> seek(double positionSeconds) =>
      _activeBackend?.seek(positionSeconds) ?? Future.value();

  void setPlaybackRate(double rate) {
    state = state.copyWith(playbackRate: rate);
    _rateDebounce?.cancel();
    _rateDebounce = Timer(
      const Duration(milliseconds: 80),
      () => _activeBackend?.setPlaybackRate(rate),
    );
  }

  void toggleLoop() {
    if (state.isLooping) {
      state = state.copyWith(isLooping: false);
    } else {
      final end = state.duration > 0 ? state.duration : 60.0;
      state = AudioPlayerState(
        trackUri: state.trackUri,
        status: state.status,
        position: state.position,
        duration: state.duration,
        title: state.title,
        subtitle: state.subtitle,
        playbackRate: state.playbackRate,
        isLooping: true,
        loopEnd: end,
      );
    }
  }

  void setLoopBounds(double start, double end) {
    state = state.copyWith(loopStart: start, loopEnd: end);
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
      AudioPlayerNotifier.new,
    );
