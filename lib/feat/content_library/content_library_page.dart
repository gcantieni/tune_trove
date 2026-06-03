import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_refresh_indicator.dart';
import 'package:tune_trove/feat/content_library/source_confirmation_dialog.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentLibraryPage extends ConsumerWidget {
  const ContentLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedIds = ref.watch(confirmedSourcesProvider);

    final defaultSources =
        allContentSources.where((m) => m.isAlwaysActive && !m.hidden).toList()
          ..sort(compareSourcesForDisplay);
    final optionalSources =
        allContentSources.where((m) => !m.isAlwaysActive && !m.hidden).toList()
          ..sort(compareSourcesForDisplay);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => navScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Content Library'),
      ),
      body: SyncRefreshIndicator(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Search Order'),
              subtitle: const Text(
                'Set the order results appear from each source',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/content_library/search_order'),
            ),
            const Divider(height: 1),
            const _SectionHeader('Public domain sources'),
            const _SectionDescription(
              'These collections are included by default. '
              'Toggle any off to exclude them from search.',
            ),
            for (final meta in defaultSources)
              _SourceTile(
                meta: meta,
                isActive: confirmedIds.contains(meta.id),
                onToggle: (isCurrentlyActive) => isCurrentlyActive
                    ? ref
                          .read(confirmedSourcesProvider.notifier)
                          .revoke(meta.id)
                    : ref
                          .read(confirmedSourcesProvider.notifier)
                          .confirm(meta.id, meta.license),
              ),
            const SizedBox(height: 8),
            const _SectionHeader('Additional sources'),
            const _SectionDescription(
              'These sources are licensed for personal, non-commercial use. '
              'Tap a source to review its license terms and activate it.',
            ),
            for (final meta in optionalSources)
              _SourceTile(
                meta: meta,
                isActive: confirmedIds.contains(meta.id),
                onToggle: (isCurrentlyActive) => isCurrentlyActive
                    ? _deactivate(context, ref, meta)
                    : _activate(context, ref, meta),
              ),
            const _CopyrightFooter(),
          ],
        ),
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
          'Tunes you already imported will be hidden.',
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
  final void Function(bool isCurrentlyActive) onToggle;

  const _SourceTile({
    required this.meta,
    required this.isActive,
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
          Row(
            children: [
              _GenreChip(meta.genre),
              const SizedBox(width: 6),
              Text(meta.license, style: theme.textTheme.bodySmall),
            ],
          ),
          if (isActive && !meta.isAlwaysActive)
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
      isThreeLine: isActive && !meta.isAlwaysActive,
      trailing: Switch(value: isActive, onChanged: (_) => onToggle(isActive)),
      onTap: () => onToggle(isActive),
    );
  }
}

class _CopyrightFooter extends StatelessWidget {
  const _CopyrightFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('mailto:copyright@yeskenney.com'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text.rich(
          TextSpan(
            text: 'Copyright questions or concerns? ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: 'Email us at copyright@yeskenney.com',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String genre;
  const _GenreChip(this.genre);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        genre,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
