import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/feat/recording_list/recording_list_item.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class RecordingListPage extends StatelessWidget {
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
            children: [RecordingListWidget()],
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

  void _showAddRecordingDialog(BuildContext context) {
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
