import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/recording_list/recording_file_store.dart';
import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/feat/recording_list/recording_list_item.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class RecordingListPage extends ConsumerStatefulWidget {
  const RecordingListPage({super.key});

  @override
  ConsumerState<RecordingListPage> createState() => _RecordingListPageState();
}

class _RecordingListPageState extends ConsumerState<RecordingListPage> {
  StreamSubscription<SharedAudioFile>? _sharedFilesSub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(audioImportServiceProvider);
    _sharedFilesSub = service.incomingFiles.listen(_handleSharedFile);
    // Handle a file the app may have been cold-launched with.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await service.takeInitialSharedFile();
      if (initial != null) _handleSharedFile(initial);
    });
  }

  @override
  void dispose() {
    _sharedFilesSub?.cancel();
    super.dispose();
  }

  /// Copies an imported audio file (iOS share sheet, or macOS Finder "Open
  /// With" / drag-and-drop) into the app's audio store, then opens the recording
  /// form pre-filled with a `file://` URL.
  Future<void> _handleSharedFile(SharedAudioFile file) async {
    final String url;
    try {
      final destPath = await copyIntoAudioStore(file.path, file.name);
      url = 'file://$destPath';
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import the shared recording.')),
      );
      return;
    }
    if (!mounted) return;
    _showAddRecordingDialog(
      context,
      initialUrl: url,
      initialName: p.basenameWithoutExtension(file.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Recordings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SyncRefreshIndicator(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              RecordingListWidget(),
              SizedBox(height: MediaQuery.of(context).size.width * 0.25),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add recording',
        onPressed: () => _showAddRecordingDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRecordingDialog(
    BuildContext context, {
    String? initialUrl,
    String? initialName,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add recording',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  RecordingFormWidget(
                    initialUrl: initialUrl,
                    initialName: initialName,
                    onSubmitted: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RecordingListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fontSize = 19.0;
    final AsyncValue<List<Recording>> async = ref.watch(allRecordingsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
      data: (recordings) => Column(
        mainAxisSize: MainAxisSize.min,
        children: recordings.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No recordings saved',
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ),
                ),
              ]
            : [for (final r in recordings) RecordingListItem(recording: r)],
      ),
    );
  }
}
