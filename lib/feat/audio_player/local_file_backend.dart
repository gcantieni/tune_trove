import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tune_trove/feat/audio_player/audio_player_backend.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';

class LocalFileBackend implements AudioPlayerBackend {
  final _player = AudioPlayer();
  final _controller = StreamController<AudioPlayerState>.broadcast();
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  String _trackUri = '';
  String _title = '';
  double _duration = 0;
  AudioPlaybackStatus _status = AudioPlaybackStatus.stopped;

  LocalFileBackend() {
    _stateSub = _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed &&
          _status == AudioPlaybackStatus.playing) {
        _status = AudioPlaybackStatus.stopped;
        _emit(0);
      }
    });
    _positionSub = _player.positionStream.listen((pos) {
      if (_status == AudioPlaybackStatus.playing) {
        _emit(pos.inMilliseconds / 1000.0);
      }
    });
  }

  @override
  Stream<AudioPlayerState> get stateStream => _controller.stream;

  @override
  Future<void> play(String trackUri, {double? startTime}) async {
    _trackUri = trackUri;
    _title = _titleFromUri(trackUri);

    final audioDuration = await _player.setFilePath(pathFromTrackUri(trackUri));
    _duration = (audioDuration?.inMilliseconds ?? 0) / 1000.0;

    if (startTime != null && startTime > 0) {
      await _player.seek(Duration(milliseconds: (startTime * 1000).round()));
    }
    _player.play(); // ignore: discarded_futures — completes when track ends
    _status = AudioPlaybackStatus.playing;
    _emit(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _status = AudioPlaybackStatus.paused;
    _emit(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> resume() async {
    _player.play(); // ignore: discarded_futures
    _status = AudioPlaybackStatus.playing;
    _emit(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _status = AudioPlaybackStatus.stopped;
    _emit(0);
  }

  @override
  Future<void> seek(double positionSeconds) async {
    await _player.seek(
      Duration(milliseconds: (positionSeconds * 1000).round()),
    );
    _emit(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> setPlaybackRate(double rate) => _player.setSpeed(rate);

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    _controller.close();
  }

  void _emit(double position) {
    _controller.add(
      AudioPlayerState(
        trackUri: _trackUri,
        status: _status,
        position: position,
        duration: _duration,
        title: _title,
      ),
    );
  }

  String _titleFromUri(String uri) {
    final name = pathFromTrackUri(uri).split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// Resolves a recording URI to a filesystem path that [just_audio] can load.
/// Strips the recognized local schemes (`file://`, `app-data:`) and passes
/// anything else through unchanged.
String pathFromTrackUri(String uri) {
  if (uri.startsWith('file://')) return uri.replaceFirst('file://', '');
  if (uri.startsWith('app-data:')) return uri.replaceFirst('app-data:', '');
  return uri;
}

final localFileBackendProvider = Provider<AudioPlayerBackend>((ref) {
  final backend = LocalFileBackend();
  ref.onDispose(backend.dispose);
  return backend;
});
