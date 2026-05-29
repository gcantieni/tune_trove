import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/mock_audio_import_service.dart';
import 'package:tune_trove/feat/audio_import/platform_audio_import_service.dart';

/// Receives audio files shared or opened into the app: the iOS share sheet
/// ("Copy to Tune Trove", e.g. from Voice Memos or Files) and macOS Finder
/// "Open With" / drag-and-drop onto the window.
abstract class AudioImportService {
  /// Returns and clears any file the app was cold-launched with, or null. Safe
  /// to call multiple times; only the first call after a launch returns it.
  Future<SharedAudioFile?> takeInitialSharedFile();

  /// Emits files shared while the app is already running.
  Stream<SharedAudioFile> get incomingFiles;

  void dispose();
}

/// True on platforms with the native share-receipt bridge wired up (iOS share
/// sheet; macOS drag-and-drop / "Open With").
bool get _supportsPlatformImport =>
    !kIsWeb && (Platform.isIOS || Platform.isMacOS);

final audioImportServiceProvider = Provider<AudioImportService>((ref) {
  final service = _supportsPlatformImport
      ? PlatformAudioImportService()
      : MockAudioImportService();
  ref.onDispose(service.dispose);
  return service;
});
