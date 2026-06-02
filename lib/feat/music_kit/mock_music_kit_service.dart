import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:tune_trove/feat/music_kit/music_kit_models.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';

const _mockAsset = 'assets/song.mp3';

// Position update interval — real MusicKit fires events at ~500ms when playing.
const _positionInterval = Duration(milliseconds: 500);

const _fakeResults = [
  MusicKitSearchResult(
    kind: 'song',
    id: 'mock-001',
    title: 'The Morning Dew',
    artistName: 'Planxty',
    albumTitle: 'Cold Blow and the Rainy Night',
    durationMs: 214000,
    artworkUrl: '',
  ),
  MusicKitSearchResult(
    kind: 'song',
    id: 'mock-002',
    title: 'The Bucks of Oranmore',
    artistName: 'The Chieftains',
    albumTitle: 'The Chieftains 2',
    durationMs: 182000,
    artworkUrl: '',
  ),
  MusicKitSearchResult(
    kind: 'album',
    id: 'mock-003',
    title: 'Prosperous',
    artistName: 'Christy Moore',
    albumTitle: 'Prosperous',
    durationMs: 0,
    artworkUrl: '',
  ),
  MusicKitSearchResult(
    kind: 'artist',
    id: 'mock-004',
    title: 'The Dubliners',
    artistName: 'The Dubliners',
    albumTitle: '',
    durationMs: 0,
    artworkUrl: '',
  ),
];

class MockMusicKitService implements MusicKitService {
  final _stateController = StreamController<MusicKitPlaybackState>.broadcast();
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _positionTimer;
  MusicKitSearchResult? _currentTrack;
  String _requestedCatalogId = '';
  double _duration = 0;
  String _status = 'stopped';
  // Asset stays loaded between play/pause/seek cycles — mirrors MusicKit's
  // buffered queue. Reset only on stop() since that dequeues the item.
  bool _assetLoaded = false;

  MockMusicKitService() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _status == 'playing') {
        _status = 'stopped';
        _stopPositionTimer();
        _emitStatus(0);
      }
    });
  }

  @override
  Future<String> authorize() async => 'authorized';

  @override
  Future<String> authorizationStatus() async => 'authorized';

  @override
  Future<List<MusicKitSearchResult>> search(
    String query, {
    List<String> types = const ['songs', 'albums', 'artists'],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (query.trim().isEmpty) return [];
    return _fakeResults
        .where((r) => types.contains('${r.kind}s') || types.contains(r.kind))
        .toList();
  }

  @override
  Future<MusicKitSearchResult?> lookupSong(String catalogId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Sentinel for exercising the not-found / unresolved path in tests.
    if (catalogId == 'unknown') return null;
    // Echo the requested id with deterministic metadata so ingest tests can
    // assert a stable name without a real MusicKit backend.
    return MusicKitSearchResult(
      kind: 'song',
      id: catalogId,
      title: 'The Morning Dew',
      artistName: 'Planxty',
      albumTitle: 'Cold Blow and the Rainy Night',
      durationMs: 214000,
      artworkUrl: '',
    );
  }

  @override
  Future<void> play(MusicKitPlayParams params) async {
    _requestedCatalogId = params.catalogId;
    _currentTrack = _fakeResults.firstWhere(
      (r) => r.id == params.catalogId,
      orElse: () => _fakeResults.first,
    );

    if (!_assetLoaded) {
      final audioDuration = await _player.setAsset(_mockAsset);
      _duration = (audioDuration?.inMilliseconds ?? 0) / 1000.0;
      _assetLoaded = true;
    }

    final startMs = ((params.startTime ?? 0) * 1000).round();
    await _player.seek(Duration(milliseconds: startMs));
    _player
        .play(); // ignore: discarded_futures — completes when song ends, not on start
    _status = 'playing';
    _startPositionTimer();
    _emitStatus(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _status = 'paused';
    _stopPositionTimer();
    _emitStatus(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> resume() async {
    _player.play(); // ignore: discarded_futures
    _status = 'playing';
    _startPositionTimer();
    _emitStatus(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _status = 'stopped';
    _stopPositionTimer();
    _assetLoaded = false;
    _emitStatus(0);
  }

  @override
  Future<void> seek(double positionSeconds) async {
    await _player.seek(
      Duration(milliseconds: (positionSeconds * 1000).round()),
    );
    _emitPosition(_player.position.inMilliseconds / 1000.0);
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    await _player.setSpeed(rate);
  }

  @override
  Future<void> setRepeatMode(String mode) async {}

  @override
  Stream<MusicKitPlaybackState> get playbackState => _stateController.stream;

  @override
  void dispose() {
    _stopPositionTimer();
    _playerStateSub?.cancel();
    _player.dispose();
    _stateController.close();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(_positionInterval, (_) {
      if (_status == 'playing') {
        _emitPosition(_player.position.inMilliseconds / 1000.0);
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _emitStatus(double position) {
    _stateController.add(
      MusicKitPlaybackState(
        event: 'statusChanged',
        status: _status,
        position: position,
        duration: _duration,
        catalogId: _requestedCatalogId,
        title: _currentTrack?.title ?? '',
        artistName: _currentTrack?.artistName ?? '',
      ),
    );
  }

  void _emitPosition(double position) {
    _stateController.add(
      MusicKitPlaybackState(
        event: 'positionUpdate',
        status: _status,
        position: position,
        duration: _duration,
        catalogId: _requestedCatalogId,
        title: _currentTrack?.title ?? '',
        artistName: _currentTrack?.artistName ?? '',
      ),
    );
  }
}
