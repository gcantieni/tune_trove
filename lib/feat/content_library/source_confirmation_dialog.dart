import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a non-dismissible modal that explains the license for [meta] and
/// requires an explicit "I Understand" tap before the source is activated.
///
/// Returns `true` if the user confirmed, `false` (or null) otherwise.
Future<bool?> showSourceConfirmationDialog(
  BuildContext context,
  ContentSourceMeta meta,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SourceConfirmationDialog(meta: meta),
  );
}

class _SourceConfirmationDialog extends ConsumerWidget {
  final ContentSourceMeta meta;
  const _SourceConfirmationDialog({required this.meta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(meta.name, style: theme.textTheme.titleLarge)],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _plainLanguageExplanation(meta.license),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'License: ${meta.license}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (meta.licenseUrl != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => launchUrl(Uri.parse(meta.licenseUrl!)),
                child: Text(
                  'View full license ↗',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              meta.attribution,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(confirmedSourcesProvider.notifier)
                .confirm(meta.id, meta.license);
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: const Text('I Understand, Add This Source'),
        ),
      ],
    );
  }

  String _plainLanguageExplanation(String license) {
    if (license.contains('NC-SA')) {
      return 'This content is available free of charge for personal, '
          'non-commercial use. You may not use it to generate income or '
          'include it in commercial products. If you share or adapt it, '
          'you must give credit and apply the same license.';
    }
    if (license.contains('non-commercial')) {
      return 'This content is freely available for personal, non-commercial '
          'use only. Commercial use is not permitted.';
    }
    if (license.contains('CC BY')) {
      return 'This content is available under a Creative Commons license. '
          'You may use and share it freely provided you give attribution.';
    }
    return 'This content is available under the terms described below. '
        'Please review the license before proceeding.';
  }
}
