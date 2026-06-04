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

  /// Section label for a genre; ungenred sources are grouped as "Multi-genre".
  static String _genreLabel(String genre) =>
      genre.isEmpty ? 'Multi-genre' : genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedIds = ref.watch(confirmedSourcesProvider);

    // Sorted so same-genre sources are consecutive (Irish → Scottish →
    // English → other genres → Multi-genre, thesession.org last).
    final sources = allContentSources.where((m) => !m.hidden).toList()
      ..sort(compareSourcesForDisplay);

    final sourceWidgets = <Widget>[];
    String? currentGenre;
    for (final meta in sources) {
      if (meta.genre != currentGenre) {
        currentGenre = meta.genre;
        sourceWidgets.add(_SectionHeader(_genreLabel(meta.genre)));
      }
      sourceWidgets.add(
        _SourceTile(
          meta: meta,
          isActive: confirmedIds.contains(meta.id),
          onToggle: (isActive) =>
              _toggleSource(context, ref, meta, isActive: isActive),
        ),
      );
    }

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
            ...sourceWidgets,
            const _CopyrightFooter(),
          ],
        ),
      ),
    );
  }

  void _toggleSource(
    BuildContext context,
    WidgetRef ref,
    ContentSourceMeta meta, {
    required bool isActive,
  }) {
    // Public-domain sources toggle directly; licensed sources go through the
    // confirmation / removal dialogs.
    if (meta.isAlwaysActive) {
      final notifier = ref.read(confirmedSourcesProvider.notifier);
      if (isActive) {
        notifier.revoke(meta.id);
      } else {
        notifier.confirm(meta.id, meta.license);
      }
    } else if (isActive) {
      _deactivate(context, ref, meta);
    } else {
      _activate(context, ref, meta);
    }
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
          Text(meta.license, style: theme.textTheme.bodySmall),
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
