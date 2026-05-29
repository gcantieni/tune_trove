import 'dart:async';

import 'package:flutter/services.dart';

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';

const _methodChannel = MethodChannel('com.gcantieni.tuneTrove/audio_import');
const _eventChannel = EventChannel(
  'com.gcantieni.tuneTrove/audio_import_events',
);

class PlatformAudioImportService implements AudioImportService {
  StreamSubscription<dynamic>? _sub;
  final _filesController = StreamController<SharedAudioFile>.broadcast();

  PlatformAudioImportService() {
    _sub = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final file = SharedAudioFile.fromMap(event.cast());
        if (file != null) _filesController.add(file);
      }
    }, onError: _filesController.addError);
  }

  @override
  Future<SharedAudioFile?> takeInitialSharedFile() async {
    final raw = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getInitialSharedFile',
    );
    if (raw == null) return null;
    return SharedAudioFile.fromMap(raw);
  }

  @override
  Stream<SharedAudioFile> get incomingFiles => _filesController.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _filesController.close();
  }
}
