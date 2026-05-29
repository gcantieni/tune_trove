import 'dart:async';

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';

/// No-op implementation for platforms without the native share-receipt bridge
/// (Android, desktop, web) and for tests.
class MockAudioImportService implements AudioImportService {
  final _controller = StreamController<SharedAudioFile>.broadcast();

  @override
  Future<SharedAudioFile?> takeInitialSharedFile() async => null;

  @override
  Stream<SharedAudioFile> get incomingFiles => _controller.stream;

  /// Test hook: simulate a file shared into the running app.
  void emit(SharedAudioFile file) => _controller.add(file);

  @override
  void dispose() => _controller.close();
}
