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
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _key;
  String? _genre;
  final _fromController = TextEditingController();
  final _abcController = TextEditingController();
  TuneType? _type;
  TuneStatus? _status;

  @override
  void dispose() {
    _nameController.dispose();
    _fromController.dispose();
    _abcController.dispose();
    super.dispose();
  }

  // Canonical genres, plus the current value if it predates the list (e.g.
  // synced from another device or imported with a legacy free-text genre) so
  // the dropdown can render it without crashing and editing won't drop it.
  List<String> get _genreOptions {
    final current = _genre;
    if (current == null || kTuneGenres.contains(current)) return kTuneGenres;
    return [...kTuneGenres, current];
  }

  void _enterEdit(Tune tune) {
    _nameController.text = tune.name;
    _key = tune.key != null ? normalizePickerKey(tune.key!) : null;
    _genre = (tune.genre?.isEmpty ?? true) ? null : tune.genre;
    _fromController.text = tune.from ?? '';
    _abcController.text = tune.abc ?? '';
    _type = tune.type;
    _status = tune.status;
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
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

  Future<void> _save(Tune tune) async {
    if (!_formKey.currentState!.validate()) return;

    final keyText = _key ?? '';
    final fromText = _fromController.text.trim();
    final abcText = _abcController.text.trim();
    final newAbc = abcText.isEmpty ? null : abcText;
    final abcChanged = newAbc != tune.abc;

    final dao = ref.read(databaseProvider).tuneDao;
    await dao.updateTune(
      TunesCompanion(
        id: drift.Value(tune.id),
        name: drift.Value(_nameController.text.trim()),
        key: drift.Value(keyText.isEmpty ? null : keyText),
        genre: drift.Value(_genre),
        from: drift.Value(fromText.isEmpty ? null : fromText),
        abc: drift.Value(newAbc),
        // Invalidate the cached SVG when ABC changes; the renderer
        // call below will fill it in (or leave it null on failure).
        abcSvg: abcChanged
            ? const drift.Value<String?>(null)
            : const drift.Value.absent(),
        type: drift.Value(_type),
        status: drift.Value(_status),
        modifiedAt: drift.Value(DateTime.now()),
      ),
    );

    if (!mounted) return;
    setState(() => _editing = false);

    // Fire-and-forget render. UI shows plaintext fallback meanwhile.
    if (abcChanged && newAbc != null) {
      unawaited(_renderAndCacheSvg(tune.id, newAbc));
    }
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
                  onPressed: () => _save(tune),
                ),
              ];
            }
            return [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete tune',
                onPressed: () => _confirmDelete(tune),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: () => _enterEdit(tune),
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
          return _editing ? _buildEditForm(tune) : _buildReadView(tune);
        },
      ),
    );
  }

  Widget _buildReadView(Tune tune) {
    final statusLabel = tuneStatusToString(tune.status);
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
        _readRow('Name', tune.name),
        _readRow('Key', tune.key ?? '—'),
        _readRow('Type', tune.type?.name ?? '—'),
        _readRow('Genre', (tune.genre?.isEmpty ?? true) ? '—' : tune.genre!),
        _readRow('Status', statusLabel.isEmpty ? '—' : statusLabel),
        _readRow('From', (tune.from?.isEmpty ?? true) ? '—' : tune.from!),
        _SourceAttribution(sourceName: tune.from),
        const SizedBox(height: 16),
        const Text('ABC', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AbcView(abc: tune.abc, svg: tune.abcSvg),
        const SizedBox(height: 8),
        AbcPlayButton(abc: tune.abc),
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

  Widget _buildEditForm(Tune tune) {
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
          InkWell(
            onTap: () async {
              final result = await showKeyPickerSheet(
                context,
                currentKey: _key,
              );
              if (result != null) {
                setState(() => _key = result.isEmpty ? null : result);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Key'),
              child: Text(
                _key != null && _key!.isNotEmpty ? _key! : '—',
                style: TextStyle(
                  color: _key != null && _key!.isNotEmpty
                      ? null
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TuneType?>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              const DropdownMenuItem<TuneType?>(child: Text('—')),
              for (final t in TuneType.values)
                DropdownMenuItem<TuneType?>(value: t, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _genre,
            decoration: const InputDecoration(labelText: 'Genre'),
            items: [
              const DropdownMenuItem<String?>(child: Text('—')),
              for (final g in _genreOptions)
                DropdownMenuItem<String?>(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _genre = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TuneStatus?>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem<TuneStatus?>(child: Text('—')),
              for (final s in TuneStatus.values)
                DropdownMenuItem<TuneStatus?>(
                  value: s,
                  child: Text(tuneStatusToString(s)),
                ),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fromController,
            decoration: const InputDecoration(labelText: 'From'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _abcController,
            decoration: const InputDecoration(
              labelText: 'ABC',
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        title: Text(entry.tuneSet.name),
        onTap: () => context.push('/set_list/${entry.tuneSet.id}'),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Remove from set',
          onPressed: () => ref
              .read(databaseProvider)
              .setTuneDao
              .removeTuneFromSet(entry.link.id),
        ),
      ),
    );
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

    return Card(
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
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          recording.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove from tune',
                      onPressed: () => ref
                          .read(databaseProvider)
                          .tuneRecordingDao
                          .unlinkTuneFromRecording(
                            link.tuneId,
                            link.recordingId,
                          ),
                    ),
                  ],
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
    );
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
  final String? sourceName;
  const _SourceAttribution({required this.sourceName});

  @override
  Widget build(BuildContext context) {
    final meta = metaBySourceName(allContentSources, sourceName);
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
