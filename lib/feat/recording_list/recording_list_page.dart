import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/audio_import/audio_import_controller.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/music_kit/apple_music_link.dart';
import 'package:tune_trove/feat/recording_list/add_recording_dialog.dart';
import 'package:tune_trove/feat/recording_list/recording_filter_bar.dart';
import 'package:tune_trove/feat/recording_list/recording_filters.dart';
import 'package:tune_trove/feat/recording_list/recording_list_item.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

/// Recordings tab. Shared-file import (cold launch, share sheet, resume re-drain)
/// is owned app-wide by `AudioImportController`, so this page only renders the
/// list and the manual "add recording" FAB.
class RecordingListPage extends ConsumerWidget {
  const RecordingListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Recordings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Add from Apple Music link',
            onPressed: () => _addFromClipboard(context, ref),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SyncRefreshIndicator(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const RecordingFilterBar(),
              RecordingListWidget(),
              SizedBox(height: MediaQuery.of(context).size.width * 0.25),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add recording',
        onPressed: () => showAddRecordingDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Reads the clipboard and, if it holds an Apple Music link, ingests it as a
  /// `music-catalog:` recording (the inverse of in-app search) via the app-root
  /// import controller — which resolves the name and opens the prefilled form.
  Future<void> _addFromClipboard(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!isAppleMusicShareUrl(text)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Copy an Apple Music link first.')),
      );
      return;
    }
    await ref.read(audioImportControllerProvider).ingestUrl(text);
  }
}

class RecordingListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fontSize = 19.0;
    final filters = ref.watch(recordingFiltersProvider);
    final AsyncValue<List<Recording>> async = ref.watch(
      filteredRecordingsProvider,
    );

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error: $err'),
      data: (recordings) => Column(
        mainAxisSize: MainAxisSize.min,
        children: recordings.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      filters.isActive
                          ? 'No recordings match your filters'
                          : 'No recordings saved',
                      style: const TextStyle(fontSize: fontSize),
                    ),
                  ),
                ),
              ]
            : [for (final r in recordings) RecordingListItem(recording: r)],
      ),
    );
  }
}
