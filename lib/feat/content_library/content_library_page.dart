import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/content_library/source_confirmation_dialog.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

class ContentLibraryPage extends ConsumerWidget {
  const ContentLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedIds = ref.watch(confirmedSourcesProvider);

    final alwaysActive = allContentSources
        .where((m) => m.isAlwaysActive)
        .toList();
    final requiresConfirmation = allContentSources
        .where((m) => !m.isAlwaysActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Content Library'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Always active'),
          const _SectionDescription(
            'These sources contain public-domain tunes and are active by default.',
          ),
          for (final meta in alwaysActive)
            _SourceTile(
              meta: meta,
              isActive: true,
              isAlwaysActive: true,
              onToggle: null,
            ),
          const SizedBox(height: 8),
          const _SectionHeader('Additional sources'),
          const _SectionDescription(
            'These sources are licensed for personal, non-commercial use. '
            'Tap a source to review its license terms and activate it.',
          ),
          for (final meta in requiresConfirmation)
            _SourceTile(
              meta: meta,
              isActive: confirmedIds.contains(meta.id),
              isAlwaysActive: false,
              onToggle: (isActive) => isActive
                  ? _deactivate(context, ref, meta)
                  : _activate(context, ref, meta),
            ),
        ],
      ),
    );
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    ContentSourceMeta meta,
  ) async {
    await showSourceConfirmationDialog(context, meta);
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    ContentSourceMeta meta,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove source'),
        content: Text(
          'Remove "${meta.name}" from your active sources? '
          'Tunes you already imported will not be affected.',
        ),
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
    if (confirmed == true) {
      await ref.read(confirmedSourcesProvider.notifier).revoke(meta.id);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionDescription extends StatelessWidget {
  final String text;
  const _SectionDescription(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final ContentSourceMeta meta;
  final bool isActive;
  final bool isAlwaysActive;
  final void Function(bool isCurrentlyActive)? onToggle;

  const _SourceTile({
    required this.meta,
    required this.isActive,
    required this.isAlwaysActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(meta.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta.license, style: theme.textTheme.bodySmall),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                meta.attribution,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      isThreeLine: isActive,
      trailing: isAlwaysActive
          ? Chip(
              label: const Text('Active'),
              backgroundColor: theme.colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 12,
              ),
              side: BorderSide.none,
            )
          : Switch(
              value: isActive,
              onChanged: onToggle == null ? null : (_) => onToggle!(isActive),
            ),
      onTap: onToggle == null ? null : () => onToggle!(isActive),
    );
  }
}
