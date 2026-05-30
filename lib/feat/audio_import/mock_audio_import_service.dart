import 'dart:async';
import 'dart:collection';

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';

/// No-op implementation for platforms without the native share-receipt bridge
/// (Android, desktop, web) and for tests.
class MockAudioImportService implements AudioImportService {
  final _controller = StreamController<SharedAudioFile>.broadcast();
  final Queue<SharedAudioFile> _initialQueue = Queue<SharedAudioFile>();

  @override
  Future<SharedAudioFile?> takeInitialSharedFile() async =>
      _initialQueue.isEmpty ? null : _initialQueue.removeFirst();

  @override
  Stream<SharedAudioFile> get incomingFiles => _controller.stream;

  /// Test hook: simulate a file shared into the running app.
  void emit(SharedAudioFile file) => _controller.add(file);

  /// Test hook: queue a file to be returned by [takeInitialSharedFile], as if a
  /// Share Extension had dropped it in the App Group container while the app was
  /// backgrounded.
  void enqueueInitial(SharedAudioFile file) => _initialQueue.add(file);

  @override
  void dispose() => _controller.close();
}
