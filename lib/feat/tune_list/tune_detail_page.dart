import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/abc_midi/abc_play_button.dart';
import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:tune_trove/feat/abc_render/abc_view.dart';
import 'package:tune_trove/feat/tune_list/tune_list_item.dart';
import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/model/accessors/tune_recording_dao.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/sets_provider.dart';
import 'package:tune_trove/model/providers/tune_recording_provider.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/model/tune_genres.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';
import 'package:tune_trove/shared_widgets/recording_picker_dialog.dart';
import 'package:tune_trove/shared_widgets/timestamp_editor_dialog.dart';

class TuneDetailPage extends ConsumerStatefulWidget {
  final int tuneId;

  const TuneDetailPage({required this.tuneId, super.key});

  @override
  ConsumerState<TuneDetailPage> createState() => _TuneDetailPageState();
}

class _TuneDetailPageState extends ConsumerState<TuneDetailPage> {
  // Inline ABC editing state. The pencil below the ABC rendering toggles
  // [_editingAbc]; while editing, the rendering above the field previews the
  // controller's live text ([_liveSvg], re-rendered on a short debounce).
  bool _editingAbc = false;
  final _abcController = TextEditingController();
  String? _liveSvg;
  Timer? _abcDebounce;
  int _renderToken = 0;

  @override
  void dispose() {
    _abcDebounce?.cancel();
    _abcController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Tune tune) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete tune'),
        content: Text('Delete "${tune.name}"? This cannot be undone.'),
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
    await ref.read(databaseProvider).tuneDao.deleteTune(tune.id);
    if (!mounted) return;
    context.pop();
  }

  Future<void> _renderAndCacheSvg(int tuneId, String abc) async {
    final renderer = ref.read(abcRendererProvider);
    final svg = await renderer.render(abc);
    if (svg == null) return;
    await ref
        .read(databaseProvider)
        .tuneDao
        .updateTune(
          TunesCompanion(id: drift.Value(tuneId), abcSvg: drift.Value(svg)),
        );
  }

  void _enterAbcEdit(Tune tune) {
    _abcController.text = tune.abc ?? '';
    setState(() {
      _editingAbc = true;
      _liveSvg = tune.abcSvg;
    });
  }

  void _cancelAbcEdit() {
    _abcDebounce?.cancel();
    setState(() => _editingAbc = false);
  }

  /// Re-render the live preview on a short debounce as the user types, so the
  /// notation above the field tracks the ABC text. The plaintext fallback
  /// updates immediately via setState; the SVG lags by [_renderToken]-guarded
  /// renders to drop results from superseded keystrokes.
  void _onAbcChanged(String value) {
    setState(() {}); // reflect the new text in the preview/play button
    _abcDebounce?.cancel();
    final token = ++_renderToken;
    _abcDebounce = Timer(const Duration(milliseconds: 400), () async {
      final text = value.trim();
      if (text.isEmpty) {
        if (mounted && token == _renderToken) setState(() => _liveSvg = null);
        return;
      }
      final svg = await ref.read(abcRendererProvider).render(text);
      if (!mounted || token != _renderToken) return;
      setState(() => _liveSvg = svg);
    });
  }

  Future<void> _saveAbc(Tune tune) async {
    _abcDebounce?.cancel();
    final text = _abcController.text.trim();
    final newAbc = text.isEmpty ? null : text;
    // Render fresh so the cached SVG matches exactly what we persist, rather
    // than trusting a possibly-stale debounced preview.
    final svg = newAbc == null
        ? null
        : await ref.read(abcRendererProvider).render(newAbc);
    await _writeField(
      tune.id,
      TunesCompanion(
        id: drift.Value(tune.id),
        abc: drift.Value(newAbc),
        abcSvg: drift.Value(svg),
      ),
    );
    if (!mounted) return;
    setState(() => _editingAbc = false);
  }

  @override
  Widget build(BuildContext context) {
    final tuneAsync = ref.watch(singleTuneProvider(widget.tuneId));

    return Scaffold(
      appBar: AppBar(
        title: tuneAsync.maybeWhen(
          data: (tune) => Text(tune?.name ?? 'Tune'),
          orElse: () => const Text('Tune'),
        ),
        actions: tuneAsync.maybeWhen(
          data: (tune) {
            if (tune == null) return const <Widget>[];
            return [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete tune',
                onPressed: () => _confirmDelete(tune),
              ),
            ];
          },
          orElse: () => const <Widget>[],
        ),
      ),
      body: tuneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (tune) {
          if (tune == null) {
            return const Center(child: Text('Tune not found'));
          }
          return _buildReadView(tune);
        },
      ),
    );
  }

  Widget _buildReadView(Tune tune) {
    // Backfill: if a tune has ABC but no cached SVG (existing rows
    // pre-dating the column, or a previous render failure), kick off
    // a render in the background.
    if (tune.abc != null && tune.abc!.isNotEmpty && tune.abcSvg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _renderAndCacheSvg(tune.id, tune.abc!);
      });
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).size.width * 0.25,
      ),
      children: [
        _quickEditRow(
          label: 'Name',
          value: tune.name,
          emptyHint: 'Set name…',
          onTap: () => _quickEditName(tune),
        ),
        _quickEditRow(
          label: 'Composer',
          value: tune.composer,
          emptyHint: 'Set composer…',
          onTap: () => _quickEditComposer(tune),
        ),
        _quickEditRow(
          label: 'Key',
          value: tune.key,
          emptyHint: 'Set key…',
          onTap: () => _quickEditKey(tune),
        ),
        _quickEditRow(
          label: 'Type',
          value: tune.type?.name,
          emptyHint: 'Set type…',
          onTap: () => _quickEditType(tune),
        ),
        _quickEditRow(
          label: 'Genre',
          value: tune.genre,
          emptyHint: 'Set genre…',
          onTap: () => _quickEditGenre(tune),
        ),
        _readRowChild(
          'Status',
          Align(
            alignment: Alignment.centerLeft,
            child: TuneStatusQuickEdit(tune: tune, showLabel: true),
          ),
        ),
        _quickEditRow(
          label: 'From',
          value: tune.from,
          emptyHint: 'Set who you learned it from…',
          onTap: () => _quickEditFrom(tune),
        ),
        if (tune.source != null && tune.source!.isNotEmpty)
          _readRowChild('Source', _SourceValue(sourceId: tune.source)),
        _SourceAttribution(sourceId: tune.source),
        const SizedBox(height: 16),
        const Text('ABC', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AbcView(
          abc: _editingAbc ? _abcController.text : tune.abc,
          svg: _editingAbc ? _liveSvg : tune.abcSvg,
        ),
        const SizedBox(height: 4),
        if (!_editingAbc)
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit ABC',
              onPressed: () => _enterAbcEdit(tune),
            ),
          )
        else ...[
          TextField(
            controller: _abcController,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'ABC',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            onChanged: _onAbcChanged,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelAbcEdit,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _saveAbc(tune),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        AbcPlayButton(abc: _editingAbc ? _abcController.text : tune.abc),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Recordings',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add recording'),
              onPressed: () => _showAddRecordingDialog(tune.id),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _LinkedRecordings(tuneId: tune.id),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Sets',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add to set'),
              onPressed: () => _showAddToSetDialog(tune.id),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _LinkedSets(tuneId: tune.id),
      ],
    );
  }

  void _showAddToSetDialog(int tuneId) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddToSetDialog(tuneId: tuneId),
    );
  }

  void _showAddRecordingDialog(int tuneId) {
    final dao = ref.read(databaseProvider).tuneRecordingDao;
    showDialog<void>(
      context: context,
      builder: (_) => RecordingPickerDialog(
        title: 'Add recording for tune',
        onPicked: (recording) {
          dao.linkTuneToRecording(tuneId, recording.id);
        },
        onCreateNew: (companion) {
          dao.createRecordingAndLink(companion, tuneId);
        },
      ),
    );
  }

  /// A read row whose value is tappable to quick-edit. Shows [value], or
  /// [emptyHint] (dimmed) when there's nothing set yet.
  Widget _quickEditRow({
    required String label,
    required String? value,
    required String emptyHint,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return _readRowChild(
      label,
      Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              hasValue ? value : emptyHint,
              style: hasValue
                  ? null
                  : TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _writeField(int tuneId, TunesCompanion changes) => ref
      .read(databaseProvider)
      .tuneDao
      .updateTune(changes.copyWith(modifiedAt: drift.Value(DateTime.now())));

  Future<void> _quickEditKey(Tune tune) async {
    final result = await showKeyPickerSheet(context, currentKey: tune.key);
    // null = dismissed; empty string = explicit clear.
    if (result == null || !mounted) return;
    await _writeField(
      tune.id,
      TunesCompanion(
        id: drift.Value(tune.id),
        key: drift.Value(result.isEmpty ? null : result),
      ),
    );
  }

  Future<void> _quickEditType(Tune tune) async {
    final result = await showModalBottomSheet<_Pick<TuneType?>>(
      context: context,
      builder: (_) => _OptionPickerSheet<TuneType?>(
        title: 'Set type',
        current: tune.type,
        options: [
          const _PickOption<TuneType?>(value: null, label: '—'),
          for (final t in TuneType.values)
            _PickOption<TuneType?>(value: t, label: t.name),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await _writeField(
      tune.id,
      TunesCompanion(id: drift.Value(tune.id), type: drift.Value(result.value)),
    );
  }

  Future<void> _quickEditGenre(Tune tune) async {
    // Keep any current value that predates the canonical list so it stays
    // selectable and isn't silently dropped.
    final current = tune.genre;
    final options = <String?>[
      null,
      ...kTuneGenres,
      if (current != null &&
          current.isNotEmpty &&
          !kTuneGenres.contains(current))
        current,
    ];
    final result = await showModalBottomSheet<_Pick<String?>>(
      context: context,
      builder: (_) => _OptionPickerSheet<String?>(
        title: 'Set genre',
        current: current,
        options: [
          for (final g in options)
            _PickOption<String?>(value: g, label: g ?? '—'),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await _writeField(
      tune.id,
      TunesCompanion(
        id: drift.Value(tune.id),
        genre: drift.Value(result.value),
      ),
    );
  }

  /// Prompts for a single free-text value. Returns the entered string (which
  /// may be empty, meaning an explicit clear) or null if the dialog was
  /// dismissed/cancelled.
  Future<String?> _promptText({
    required String title,
    required String label,
    required String initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          // These fields hold names of people or tunes, so capitalize words.
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _quickEditName(Tune tune) async {
    final result = await _promptText(
      title: 'Set name',
      label: 'Name',
      initial: tune.name,
    );
    // null = dismissed/cancelled. Name is required, so ignore an empty value
    // rather than clearing it.
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty) return;
    await _writeField(
      tune.id,
      TunesCompanion(id: drift.Value(tune.id), name: drift.Value(trimmed)),
    );
  }

  Future<void> _quickEditComposer(Tune tune) async {
    final result = await _promptText(
      title: 'Set composer',
      label: 'Composer',
      initial: tune.composer ?? '',
    );
    // null = dismissed/cancelled; empty string = explicit clear.
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    await _writeField(
      tune.id,
      TunesCompanion(
        id: drift.Value(tune.id),
        composer: drift.Value(trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  Future<void> _quickEditFrom(Tune tune) async {
    final result = await _promptText(
      title: 'Set source',
      label: 'From',
      initial: tune.from ?? '',
    );
    // null = dismissed/cancelled; empty string = explicit clear.
    if (result == null || !mounted) return;
    final trimmed = result.trim();
    await _writeField(
      tune.id,
      TunesCompanion(
        id: drift.Value(tune.id),
        from: drift.Value(trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  Widget _readRowChild(String label, Widget child) {
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
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LinkedSets extends ConsumerWidget {
  final int tuneId;
  const _LinkedSets({required this.tuneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(setsForTuneProvider(tuneId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Text('Error: $e'),
      data: (entries) {
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Not in any sets yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: [for (final e in entries) _LinkedSetRow(entry: e)],
        );
      },
    );
  }
}

class _LinkedSetRow extends ConsumerWidget {
  final TuneSetEntry entry;
  const _LinkedSetRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('linked-set-${entry.link.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmRemove(context),
      onDismissed: (_) => ref
          .read(databaseProvider)
          .setTuneDao
          .removeTuneFromSet(entry.link.id),
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
        child: ListTile(
          title: Text(entry.tuneSet.name),
          onTap: () => context.push('/set_list/${entry.tuneSet.id}'),
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from set'),
        content: Text('Remove this tune from "${entry.tuneSet.name}"?'),
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
}

class _AddToSetDialog extends ConsumerWidget {
  final int tuneId;
  const _AddToSetDialog({required this.tuneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSetsAsync = ref.watch(allSetsProvider);
    final currentEntriesAsync = ref.watch(setsForTuneProvider(tuneId));

    return allSetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AlertDialog(content: Text('Error: $e')),
      data: (allSets) {
        final currentSetIds =
            currentEntriesAsync.value?.map((e) => e.tuneSet.id).toSet() ?? {};
        final available = allSets
            .where((s) => !currentSetIds.contains(s.id))
            .toList();

        return SimpleDialog(
          title: const Text('Add to set'),
          children: [
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'No other sets available. Create a set first.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              for (final s in available)
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref
                        .read(databaseProvider)
                        .setTuneDao
                        .addTuneToSet(s.id, tuneId);
                  },
                  child: Text(s.name),
                ),
          ],
        );
      },
    );
  }
}

class _LinkedRecordings extends ConsumerWidget {
  final int tuneId;
  const _LinkedRecordings({required this.tuneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recordingsForTuneProvider(tuneId));
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
              'No recordings linked yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: [for (final e in links) _LinkedRecordingRow(entry: e)],
        );
      },
    );
  }
}

class _LinkedRecordingRow extends ConsumerWidget {
  final LinkedRecording entry;
  const _LinkedRecordingRow({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recording = entry.recording;
    final link = entry.link;
    final subtitle = (recording.performers?.isEmpty ?? true)
        ? null
        : recording.performers;

    return Dismissible(
      key: ValueKey('linked-recording-${link.tuneId}-${link.recordingId}'),
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
            onTap: () => context.push('/recording_list/${recording.id}'),
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
                      recording.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _editTimes(context, ref),
                        child: Text(
                          [
                            '${formatTime(link.startTime)} – ${formatTime(link.endTime)}',
                            if (link.performedKey != null &&
                                link.performedKey!.isNotEmpty)
                              link.performedKey!,
                          ].join('  ·  '),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
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
        title: const Text('Remove recording'),
        content: Text('Remove "${entry.recording.name}" from this tune?'),
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
}

/// Shows attribution for licensed sources (NC-SA etc.) on the tune detail
/// screen. Required by license terms — must be visible on the same screen as
/// the content.
class _SourceAttribution extends StatelessWidget {
  final String? sourceId;
  const _SourceAttribution({required this.sourceId});

  @override
  Widget build(BuildContext context) {
    final meta = metaBySourceId(allContentSources, sourceId);
    if (meta == null || meta.isAlwaysActive) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        meta.attribution,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Read-only display of a tune's ABC provenance: the registry source's display
/// name (falling back to the raw id for content from an unknown/newer source).
/// Not editable — provenance is set at import and must not be user-overwritten.
class _SourceValue extends StatelessWidget {
  final String? sourceId;
  const _SourceValue({required this.sourceId});

  @override
  Widget build(BuildContext context) {
    final meta = metaBySourceId(allContentSources, sourceId);
    return Text(meta?.name ?? sourceId ?? '');
  }
}

/// Wraps a chosen value so a dismissed picker (returns null) is distinguishable
/// from an explicit "None" selection (returns `_Pick(null)`).
class _Pick<T> {
  final T value;
  const _Pick(this.value);
}

class _PickOption<T> {
  final T value;
  final String label;
  const _PickOption({required this.value, required this.label});
}

/// Bottom sheet listing a finite set of options with the current one checked.
/// Pops a [_Pick] holding the chosen value.
class _OptionPickerSheet<T> extends StatelessWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.current,
    required this.options,
  });

  final String title;
  final T current;
  final List<_PickOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final opt in options)
                  ListTile(
                    title: Text(opt.label),
                    trailing: opt.value == current
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(_Pick<T>(opt.value)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
