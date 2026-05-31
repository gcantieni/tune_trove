import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/recording_list/add_recording_dialog.dart';
import 'package:tune_trove/feat/recording_list/recording_list_item.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';
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
        onPressed: () => showAddRecordingDialog(context),
        child: const Icon(Icons.add),
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
