import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/recording_list/recording_link_kind.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';

class RecordingListItem extends ConsumerWidget {
  const RecordingListItem({required this.recording, super.key});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = recordingLinkKindOf(recording.url);
    return Dismissible(
      key: ValueKey(recording.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(databaseProvider).recordingDao.deleteRecording(recording.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        child: ListTile(
          onTap: () => context.push('/recording_list/${recording.id}'),
          leading: Icon(iconForLinkKind(kind)),
          title: Text(recording.name),
          subtitle: Text(
            recording.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recording'),
        content: Text('Delete "${recording.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
