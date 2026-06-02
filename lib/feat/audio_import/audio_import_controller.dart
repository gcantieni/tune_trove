import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';
import 'package:tune_trove/feat/music_kit/apple_music_link.dart';
import 'package:tune_trove/feat/music_kit/music_kit_constants.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';
import 'package:tune_trove/feat/recording_list/add_recording_dialog.dart';
import 'package:tune_trove/feat/recording_list/recording_file_store.dart';
import 'package:tune_trove/routing/app_router.dart';

/// App-root owner of the shared-audio import flow. Lives for the whole app
/// lifetime (constructed via [audioImportControllerProvider], watched at the app
/// root) so a file shared into Tune Trove is absorbed on *any* tab — not only
/// while the Recordings page happens to be mounted.
///
/// Responsibilities (previously owned by `RecordingListPage`):
/// - subscribe to [AudioImportService.incomingFiles];
/// - drain a cold-launch / backgrounded file via `takeInitialSharedFile()` at
///   startup and on every foreground (the `WidgetsBindingObserver` resume hook);
/// - copy the file into the audio store, then navigate to Recordings and open
///   the prefilled add-recording form.
class AudioImportController with WidgetsBindingObserver {
  AudioImportController(this._service, this._musicKit) {
    WidgetsBinding.instance.addObserver(this);
    _sub = _service.incomingFiles.listen(_handleSharedFile);
    // A file the app may have been cold-launched with.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainInitial());
  }

  final AudioImportService _service;
  final MusicKitService _musicKit;
  StreamSubscription<SharedAudioFile>? _sub;

  /// Guards against double-handling. A cold-launch `takeInitialSharedFile`, a
  /// near-simultaneous `incomingFiles` event, and a `tunetrove://` drain can all
  /// fire close together; while an import is in flight or its form is still open
  /// we ignore further files rather than stacking duplicate dialogs.
  bool _busy = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A Share Extension can drop files in the App Group container while the app
    // is backgrounded; pick them up when we return to the foreground.
    if (state == AppLifecycleState.resumed) _drainInitial();
  }

  Future<void> _drainInitial() async {
    final initial = await _service.takeInitialSharedFile();
    if (initial != null) _handleSharedFile(initial);
  }

  /// Ingests a link the user supplied in-app (e.g. the "Add from link" button
  /// pasting an Apple Music URL), reusing the same parse → resolve → surface-form
  /// path (and `_busy` guard) as a shared link.
  Future<void> ingestUrl(String url) =>
      _handleSharedFile(SharedAudioFile(url: url, name: url));

  /// Imports a shared item: a URL (e.g. an Apple Music link → a `music-catalog:`
  /// recording) or an audio file (copied into the audio store → a `file://`
  /// recording). Either way it ends by opening the prefilled add-recording form.
  Future<void> _handleSharedFile(SharedAudioFile item) async {
    if (_busy) return;
    _busy = true;
    if (item.isUrl) {
      await _handleSharedUrl(item.url!, item.name);
      return;
    }
    final String url;
    try {
      final destPath = await copyIntoAudioStore(item.path!, item.name);
      url = 'file://$destPath';
    } catch (_) {
      _showError('Could not import the shared recording.');
      _busy = false;
      return;
    }
    _surfaceForm(url: url, name: p.basenameWithoutExtension(item.name));
  }

  /// Handles a shared link. An Apple Music song link becomes a `music-catalog:`
  /// recording (the inverse of in-app MusicKit search), named from resolved
  /// catalog metadata when available, else from the link's slug. Any other URL
  /// falls back to a plain recording holding the raw link.
  Future<void> _handleSharedUrl(String sharedUrl, String fallbackName) async {
    final catalogId = appleMusicCatalogIdFromShareUrl(sharedUrl);
    if (catalogId == null) {
      _surfaceForm(url: sharedUrl, name: fallbackName);
      return;
    }
    final recordingUrl = '$kAppleMusicCatalogScheme:$catalogId';
    var name = appleMusicNameFromSlug(sharedUrl) ?? fallbackName;
    try {
      final meta = await _musicKit.lookupSong(catalogId);
      if (meta != null && meta.title.isNotEmpty) {
        name = meta.artistName.isEmpty
            ? meta.title
            : '${meta.title} — ${meta.artistName}';
      }
    } catch (_) {
      // Keep the slug-derived name on any lookup failure.
    }
    _surfaceForm(url: recordingUrl, name: name);
  }

  void _surfaceForm({required String url, required String name}) {
    // Navigate to Recordings, then open the prefilled form on the root navigator
    // so it appears regardless of the active tab. `_busy` stays set until the
    // form is dismissed, so a flurry of near-simultaneous shares opens one form.
    router.go('/recording_list');
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      _busy = false;
      return;
    }
    showAddRecordingDialog(
      context,
      initialUrl: url,
      initialName: name,
    ).whenComplete(() => _busy = false);
  }

  void _showError(String message) {
    final context = rootNavigatorKey.currentContext;
    final messenger = context == null
        ? null
        : ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
  }
}

/// Constructed once at the app root (watched in `main.dart`) so it lives for the
/// whole app lifetime and listens for shared files from any tab.
final audioImportControllerProvider = Provider<AudioImportController>((ref) {
  final controller = AudioImportController(
    ref.read(audioImportServiceProvider),
    ref.read(musicKitServiceProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
