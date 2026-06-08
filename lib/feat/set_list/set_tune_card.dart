import 'package:flutter/material.dart';

import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/routing/cross_tab_nav.dart';
import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';

class SetTuneCard extends StatelessWidget {
  const SetTuneCard({
    required this.entry,
    required this.index,
    required this.onDelete,
    required this.onKeyChanged,
    super.key,
  });

  final SetTuneEntry entry;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<String?> onKeyChanged;

  Future<void> _showKeyPicker(BuildContext context) async {
    final currentKey = entry.link.key ?? entry.tune.key;
    final result = await showKeyPickerSheet(
      context,
      currentKey: currentKey,
      defaultKey: entry.tune.key,
      clearLabel: 'Clear override',
    );
    if (result != null) {
      onKeyChanged(result.isEmpty ? null : result);
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove tune'),
        content: Text('Remove "${entry.tune.name}" from this set?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveKey = entry.link.key ?? entry.tune.key;
    final hasOverride = entry.link.key != null;

    return Dismissible(
      key: ValueKey('dismiss_${entry.link.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
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
          title: Text(entry.tune.name),
          subtitle: effectiveKey != null && effectiveKey.isNotEmpty
              ? GestureDetector(
                  onTap: () => _showKeyPicker(context),
                  child: _KeyChip(label: effectiveKey, isOverride: hasOverride),
                )
              : GestureDetector(
                  onTap: () => _showKeyPicker(context),
                  child: Text(
                    'Set key…',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
          // Drag handle — immediate drag, no long-press needed.
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          onTap: () => goCrossTab(context, '/tune_list/${entry.tune.id}'),
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.isOverride});

  final String label;
  final bool isOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverride ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isOverride ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
