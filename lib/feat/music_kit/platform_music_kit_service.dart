import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tune_trove/feat/music_kit/music_kit_models.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';

const _methodChannel = MethodChannel('com.gcantieni.tuneTrove/musickit');
const _eventChannel = EventChannel('com.gcantieni.tuneTrove/musickit_state');

class PlatformMusicKitService implements MusicKitService {
  StreamSubscription<dynamic>? _sub;
  final _stateController = StreamController<MusicKitPlaybackState>.broadcast();

  PlatformMusicKitService() {
    _sub = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _stateController.add(MusicKitPlaybackState.fromMap(event.cast()));
      }
    }, onError: _stateController.addError);
  }

  @override
  Future<String> authorize() async {
    final result = await _methodChannel.invokeMethod<String>('authorize');
    return result ?? 'unknown';
  }

  @override
  Future<String> authorizationStatus() async {
    final result = await _methodChannel.invokeMethod<String>(
      'authorizationStatus',
    );
    return result ?? 'notDetermined';
  }

  @override
  Future<List<MusicKitSearchResult>> search(
    String query, {
    List<String> types = const ['songs', 'albums', 'artists'],
  }) async {
    final raw = await _methodChannel.invokeMethod<List<dynamic>>('search', {
      'query': query,
      'types': types,
    });
    if (raw == null) return [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(MusicKitSearchResult.fromMap)
        .toList();
  }

  @override
  Future<MusicKitSearchResult?> lookupSong(String catalogId) async {
    try {
      final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'lookup',
        {'catalogId': catalogId},
      );
      if (raw == null) return null;
      return MusicKitSearchResult.fromMap(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> play(MusicKitPlayParams params) =>
      _methodChannel.invokeMethod<void>('play', params.toMap());

  @override
  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _methodChannel.invokeMethod<void>('resume');

  @override
  Future<void> stop() => _methodChannel.invokeMethod<void>('stop');

  @override
  Future<void> seek(double positionSeconds) =>
      _methodChannel.invokeMethod<void>('seek', {'position': positionSeconds});

  @override
  Future<void> setPlaybackRate(double rate) =>
      _methodChannel.invokeMethod<void>('setPlaybackRate', {'rate': rate});

  @override
  Future<void> setRepeatMode(String mode) =>
      _methodChannel.invokeMethod<void>('setRepeatMode', {'mode': mode});

  @override
  Stream<MusicKitPlaybackState> get playbackState => _stateController.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _stateController.close();
  }
}
