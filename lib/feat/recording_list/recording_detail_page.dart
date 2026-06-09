import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/feat/audio_player/audio_player_state.dart';
import 'package:tune_trove/feat/audio_player/playback_card.dart';
import 'package:tune_trove/feat/music_kit/apple_music_link.dart';
import 'package:tune_trove/feat/music_kit/music_kit_constants.dart';
import 'package:tune_trove/feat/music_kit/music_kit_notifier.dart';
import 'package:tune_trove/feat/recording_list/recording_link_kind.dart';
import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';
import 'package:tune_trove/model/providers/tune_recording_provider.dart';
import 'package:tune_trove/routing/cross_tab_nav.dart';
import 'package:tune_trove/shared_widgets/timestamp_editor_dialog.dart';
import 'package:tune_trove/shared_widgets/tune_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchUrl(BuildContext context, String url) async {
  // Apple Music recordings are stored under the internal `music-catalog:<id>`
  // scheme (for in-app MusicKit playback), which no app can open externally.
  // Rewrite it to the public Apple Music web URL so "Open URL" reaches the
  // listing instead of failing with "no application set to open the URL".
  final catalogId = catalogIdFromUrl(url);
  final target = catalogId != null
      ? appleMusicWebUrlForCatalogId(catalogId)
      : url;
  final uri = Uri.tryParse(target);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

String _withTimestamp(String url, double seconds) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final params = Map<String, String>.from(uri.queryParameters);
  params['t'] = seconds.floor().toString();
  return uri.replace(queryParameters: params).toString();
}

class RecordingDetailPage extends ConsumerStatefulWidget {
  final int recordingId;

  /// When opened from another tab via a cross-tab link, the origin location its
  /// back arrow returns to. Null when reached within the Recordings tab.
  final String? returnTo;

  const RecordingDetailPage({
    required this.recordingId,
    this.returnTo,
    super.key,
  });

  @override
  ConsumerState<RecordingDetailPage> createState() =>
      _RecordingDetailPageState();
}

class _RecordingDetailPageState extends ConsumerState<RecordingDetailPage> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _performersController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _performersController.dispose();
    super.dispose();
  }

  void _enterEdit(Recording r) {
    _nameController.text = r.name;
    _urlController.text = r.url;
    _performersController.text = r.performers ?? '';
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _openUrl(String url) => _launchUrl(context, url);

  Future<void> _confirmDelete(Recording r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recording'),
        content: Text('Delete "${r.name}"? This cannot be undone.'),
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

    if (confirmed != true) return;
    await ref.read(databaseProvider).recordingDao.deleteRecording(r.id);
    if (!mounted) return;
    context.pop();
  }

  Future<void> _save(Recording r) async {
    if (!_formKey.currentState!.validate()) return;

    final performersText = _performersController.text.trim();

    final updated = r.copyWith(
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      performers: drift.Value(performersText.isEmpty ? null : performersText),
      modifiedAt: drift.Value(DateTime.now()),
    );

    await ref.read(databaseProvider).recordingDao.updateRecording(updated);

    if (!mounted) return;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(singleRecordingProvider(widget.recordingId));

    return Scaffold(
      appBar: AppBar(
        leading: originAwareLeading(context, widget.returnTo),
        title: async.maybeWhen(
          data: (r) => Text(r?.name ?? 'Recording'),
          orElse: () => const Text('Recording'),
        ),
        actions: async.maybeWhen(
          data: (r) {
            if (r == null) return const <Widget>[];
            if (_editing) {
              return [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: _cancelEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Save',
                  onPressed: () => _save(r),
                ),
              ];
            }
            return [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete recording',
                onPressed: () => _confirmDelete(r),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () => _enterEdit(r),
              ),
            ];
          },
          orElse: () => const <Widget>[],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (r) {
          if (r == null) {
            return const Center(child: Text('Recording not found'));
          }
          return _editing ? _buildEditForm(r) : _buildReadView(r);
        },
      ),
    );
  }

  Widget _buildReadView(Recording r) {
    final kind = recordingLinkKindOf(r.url);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).size.width * 0.25,
      ),
      children: [
        _readRow('Name', r.name),
        const SizedBox(height: 8),
        if (kind == RecordingLinkKind.appleMusic)
          _AppleMusicPlayerSection(recordingUrl: r.url, title: r.name),
        if (kind == RecordingLinkKind.file)
          PlaybackCard(
            trackUri: r.url,
            title: r.name,
            leadingIcon: const Icon(Icons.audio_file_outlined, size: 20),
          ),
        Row(
          children: [
            const SizedBox(
              width: 100,
              child: Text('URL', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(iconForLinkKind(kind), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: SelectableText(
                r.url,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Open URL',
              onPressed: () => _openUrl(r.url),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy URL',
              onPressed: () => Clipboard.setData(ClipboardData(text: r.url)),
            ),
          ],
        ),
        _readRow(
          'Performers',
          (r.performers?.isEmpty ?? true) ? '—' : r.performers!,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Tunes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add tune'),
              onPressed: () => _showAddTuneDialog(r.id, r.name),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _LinkedTunes(recordingId: r.id, recordingUrl: r.url),
      ],
    );
  }

  void _showAddTuneDialog(int recordingId, String recordingName) {
    final dao = ref.read(databaseProvider).tuneRecordingDao;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TunePickerDialog(
        title: 'Add tune to recording',
        initialQuery: recordingName,
        onLibraryTune: (tune) async {
          if (!mounted) return;
          final details =
              await showDialog<
                ({double? start, double? end, String? performedKey})
              >(
                context: context,
                builder: (_) =>
                    TimestampEditorDialog(initialPerformedKey: tune.key),
              );
          if (details == null) return;
          await dao.linkTuneToRecording(
            tune.id,
            recordingId,
            startTime: details.start,
            endTime: details.end,
            performedKey: details.performedKey,
          );
        },
        onRemoteTune: (companion) {
          dao.createTuneAndLink(
            companion.copyWith(createdAt: drift.Value(DateTime.now())),
            recordingId,
          );
        },
        onCreateNew: (name) {
          dao.createTuneAndLink(
            TunesCompanion.insert(name: name, createdAt: DateTime.now()),
            recordingId,
          );
        },
      ),
    );
  }

  Widget _readRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildEditForm(Recording r) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).size.width * 0.25,
        ),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'URL'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _performersController,
            decoration: const InputDecoration(labelText: 'Performers'),
          ),
        ],
      ),
    );
  }
}

class _LinkedTunes extends ConsumerWidget {
  final int recordingId;
  final String recordingUrl;
  const _LinkedTunes({required this.recordingId, required this.recordingUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linksForRecordingProvider(recordingId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Text('Error: $e'),
      data: (links) {
        if (links.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No tunes linked yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: [
            for (final e in links)
              _LinkedTuneRow(entry: e, recordingUrl: recordingUrl),
          ],
        );
      },
    );
  }
}

class _LinkedTuneRow extends ConsumerWidget {
  final RecordedTune entry;
  final String recordingUrl;
  const _LinkedTuneRow({required this.entry, required this.recordingUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tune = entry.tune;
    final link = entry.link;
    final displayKey = (link.performedKey?.isNotEmpty ?? false)
        ? link.performedKey!
        : tune.key;
    final subtitle = [
      if (tune.type != null) tune.type!.name,
      if (displayKey != null && displayKey.isNotEmpty) displayKey,
    ].join(' · ');

    final kind = recordingLinkKindOf(recordingUrl);
    final isLocalOrApple = supportsInAppPlayback(kind);
    final playerState = ref.watch(audioPlayerProvider);
    final isThisRecordingActive = playerState.trackUri == recordingUrl;
    final showSaveLoop =
        isLocalOrApple && isThisRecordingActive && playerState.isLooping;

    return Dismissible(
      key: ValueKey('linked-tune-${link.tuneId}-${link.recordingId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(context),
      onDismissed: (_) => ref
          .read(databaseProvider)
          .tuneRecordingDao
          .unlinkTuneFromRecording(link.tuneId, link.recordingId),
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
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: () => goCrossTab(context, '/tune_list/${tune.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 4,
                top: 8,
                bottom: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      tune.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : const SizedBox.shrink(),
                      ),
                      TextButton(
                        onPressed: () => _editTimes(context, ref),
                        child: Text(
                          '${formatTime(link.startTime)} – ${formatTime(link.endTime)}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      if (kind == RecordingLinkKind.youtube &&
                          link.startTime != null)
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          tooltip: 'Open at ${formatTime(link.startTime)}',
                          onPressed: () => _launchUrl(
                            context,
                            _withTimestamp(recordingUrl, link.startTime!),
                          ),
                        ),
                      if (isLocalOrApple && link.startTime != null)
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          tooltip: 'Play from ${formatTime(link.startTime)}',
                          onPressed: () => ref
                              .read(audioPlayerProvider.notifier)
                              .playWithBounds(
                                recordingUrl,
                                start: link.startTime,
                                end: link.endTime,
                              ),
                        ),
                      if (showSaveLoop)
                        IconButton(
                          icon: const Icon(Icons.save_alt, size: 18),
                          tooltip: 'Save loop as timestamps',
                          onPressed: () => _saveLoop(ref, playerState),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove tune'),
        content: Text('Remove "${entry.tune.name}" from this recording?'),
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

  Future<void> _editTimes(BuildContext context, WidgetRef ref) async {
    final link = entry.link;
    final result =
        await showDialog<({double? start, double? end, String? performedKey})>(
          context: context,
          builder: (_) => TimestampEditorDialog(
            initialStart: link.startTime,
            initialEnd: link.endTime,
            initialPerformedKey: link.performedKey,
          ),
        );
    if (result == null) return;
    final updated = link.copyWith(
      startTime: drift.Value(result.start),
      endTime: drift.Value(result.end),
      performedKey: drift.Value(result.performedKey),
    );
    await ref.read(databaseProvider).tuneRecordingDao.updateLink(updated);
  }

  Future<void> _saveLoop(WidgetRef ref, AudioPlayerState playerState) async {
    final updated = entry.link.copyWith(
      startTime: drift.Value(playerState.loopStart),
      endTime: drift.Value(playerState.loopEnd),
    );
    await ref.read(databaseProvider).tuneRecordingDao.updateLink(updated);
  }
}

class _AppleMusicPlayerSection extends ConsumerWidget {
  final String recordingUrl;
  final String title;

  const _AppleMusicPlayerSection({
    required this.recordingUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final musicKit = ref.watch(musicKitProvider);
    return musicKit.maybeWhen(
      data: (state) {
        if (state.authStatus != 'authorized') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.library_music, size: 18),
              label: const Text('Allow Apple Music access'),
              onPressed: () => ref.read(musicKitProvider.notifier).authorize(),
            ),
          );
        }
        return PlaybackCard(
          trackUri: recordingUrl,
          title: title,
          leadingIcon: const Icon(Icons.library_music, size: 20),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
