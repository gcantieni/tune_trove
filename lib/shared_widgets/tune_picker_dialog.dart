import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/abc_midi/abc_midi_player.dart';
import 'package:tune_trove/feat/abc_midi/abc_play_button.dart';
import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:tune_trove/feat/abc_render/abc_view.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/util/relative_time.dart';
import 'package:tune_trove/util/search_normalize.dart';

const _debounceDelay = Duration(milliseconds: 350);

/// A search-driven tune picker. Shows tunes already in the library
/// (visually distinct, friendly green) alongside matches from all configured
/// tune sources, plus a "create new" affordance when there's typed text. Pops
/// itself before invoking the chosen callback.
class TunePickerDialog extends ConsumerStatefulWidget {
  final String title;

  /// Optional text to pre-fill the search box with (e.g. the title of the
  /// recording a tune is being added to). Results are shown immediately.
  final String? initialQuery;

  final void Function(Tune tune) onLibraryTune;
  final void Function(TunesCompanion tune) onRemoteTune;
  final void Function(String name) onCreateNew;

  const TunePickerDialog({
    required this.title,
    required this.onLibraryTune,
    required this.onRemoteTune,
    required this.onCreateNew,
    this.initialQuery,
    super.key,
  });

  @override
  ConsumerState<TunePickerDialog> createState() => _TunePickerDialogState();
}

class _TunePickerDialogState extends ConsumerState<TunePickerDialog> {
  late final TextEditingController _controller;
  String _debouncedQuery = '';
  Timer? _debounceTimer;
  RemoteTune? _resolvingTune;

  /// Key of the single expanded result card, if any. Keeping just one open at
  /// a time means only one [AbcPlayButton] is ever mounted, matching the
  /// single shared playback WebView.
  String? _expandedKey;

  /// Stable identity for a result card: source + tune + setting.
  String _cardKey(RemoteTune t) =>
      '${t.sourceName}|${t.sourceId}|${t.settingId}';

  /// The shared MIDI player, captured only once a card has actually been
  /// expanded (which constructs it). Lets us stop playback when the user
  /// switches cards or closes the dialog — otherwise audio that's already
  /// playing would keep looping with no button left to stop it.
  AbcMidiPlayer? _player;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    // Seed the query so a pre-filled search shows matches without waiting for
    // the debounce.
    _debouncedQuery = normalizeForSearch(_controller.text.trim());
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    // Stop any audition still playing so it doesn't loop on forever after the
    // dialog closes (e.g. right after "Use this setting").
    _player?.stop();
    super.dispose();
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(
        () => _debouncedQuery = normalizeForSearch(_controller.text.trim()),
      );
    });
  }

  void _pickLibrary(Tune tune) {
    Navigator.of(context).pop();
    widget.onLibraryTune(tune);
  }

  Future<void> _pickRemote(RemoteTune remoteTune) async {
    final sources = ref.read(tuneSourcesProvider);
    TuneSource? source;
    for (final s in sources) {
      if (s.name == remoteTune.sourceName) {
        source = s;
        break;
      }
    }
    if (source == null) return;

    setState(() => _resolvingTune = remoteTune);
    try {
      final companion = await source.resolve(remoteTune);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onRemoteTune(companion);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolvingTune = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not fetch tune: $e')));
    }
  }

  void _pickCreateNew(String name) {
    Navigator.of(context).pop();
    widget.onCreateNew(name);
  }

  @override
  Widget build(BuildContext context) {
    final query = _debouncedQuery;
    final activeSourceIds = ref.watch(activeSourceIdsProvider);
    final localTunesAsync = ref.watch(allTunesProvider);
    final remoteResultsAsync = ref.watch(tuneSearchProvider(query));

    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tune name',
                  hintText: 'Type to search…',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: query.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Start typing to find a tune.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : localTunesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Text('Error: $e'),
                        data: (localTunes) {
                          final matchingLocal = localTunes
                              .where(
                                (t) =>
                                    isSourceIdVisible(
                                      t.source,
                                      activeSourceIds,
                                    ) &&
                                    normalizeForSearch(t.name).contains(query),
                              )
                              .toList();
                          final localTsIds = localTunes
                              .where((t) => t.tsId != null)
                              .map((t) => t.tsId!)
                              .toSet();

                          return remoteResultsAsync.when(
                            loading: () => _buildList(
                              query,
                              matchingLocal,
                              localTsIds,
                              {},
                              loading: true,
                            ),
                            error: (e, s) => _buildList(
                              query,
                              matchingLocal,
                              localTsIds,
                              {},
                            ),
                            data: (remoteResults) => _buildList(
                              query,
                              matchingLocal,
                              localTsIds,
                              remoteResults,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    String query,
    List<Tune> matchingLocal,
    Set<int> localTsIds,
    Map<String, List<RemoteTune>> remoteResults, {
    bool loading = false,
  }) {
    final orderedSources = _orderedSources(remoteResults.keys);
    return ListView(
      children: [
        if (matchingLocal.isNotEmpty) ...[
          const _SectionHeader('In your library'),
          for (final t in matchingLocal)
            _LibraryTuneTile(tune: t, onTap: () => _pickLibrary(t)),
        ],
        for (final source in orderedSources) ...[
          if (matchingLocal.isNotEmpty || source != orderedSources.first)
            const SizedBox(height: 8),
          _SectionHeader('From $source'),
          for (final tune in _sortedResults(
            remoteResults[source]!,
            source,
            localTsIds,
          ))
            _RemoteResultCard(
              key: ValueKey(_cardKey(tune)),
              tune: tune,
              expanded: _expandedKey == _cardKey(tune),
              resolving: _resolvingTune == tune,
              onToggle: () => _toggleExpanded(tune),
              onUse: () => _pickRemote(tune),
            ),
        ],
        if (loading && remoteResults.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 8),
        _CreateNewTile(
          name: _controller.text.trim(),
          onTap: () => _pickCreateNew(_controller.text.trim()),
        ),
      ],
    );
  }

  void _toggleExpanded(RemoteTune tune) {
    // Stop whatever the previously-expanded card may be playing before we
    // collapse it or switch to another setting.
    _player?.stop();
    final key = _cardKey(tune);
    setState(() => _expandedKey = _expandedKey == key ? null : key);
    if (_expandedKey != null) _player ??= ref.read(abcMidiPlayerProvider);
  }

  /// Orders source names by the same priority used in the Content Library
  /// (genre-first, thesession.org last), so the unified result list groups
  /// the curated collections ahead of the broad aggregator.
  List<String> _orderedSources(Iterable<String> names) {
    ContentSourceMeta? metaFor(String name) {
      for (final m in allContentSources) {
        if (m.name == name) return m;
      }
      return null;
    }

    return names.toList()..sort((a, b) {
      final ma = metaFor(a);
      final mb = metaFor(b);
      if (ma != null && mb != null) return compareSourcesForDisplay(ma, mb);
      if (ma == null && mb == null) return a.compareTo(b);
      return ma == null ? 1 : -1;
    });
  }

  /// Within one source: drop tunes already in the library (by thesession tune
  /// id) and sort by publishing date ascending so older, more-established
  /// settings surface first. Undated results keep a stable order, after dated
  /// ones, broken by name.
  List<RemoteTune> _sortedResults(
    List<RemoteTune> results,
    String sourceName,
    Set<int> localTsIds,
  ) {
    final filtered = sourceName == 'thesession.org'
        ? results.where(
            (t) =>
                t.sourceId == null ||
                !localTsIds.contains(int.tryParse(t.sourceId!)),
          )
        : results;
    final list = filtered.toList()
      ..sort((a, b) {
        final da = a.date;
        final db = b.date;
        if (da != null && db != null) return da.compareTo(db);
        if (da == null && db == null) return a.name.compareTo(b.name);
        return da == null ? 1 : -1;
      });
    return list;
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _LibraryTuneTile extends StatelessWidget {
  final Tune tune;
  final VoidCallback onTap;
  const _LibraryTuneTile({required this.tune, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.green.shade900 : Colors.green.shade50;
    final fg = isDark ? Colors.green.shade100 : Colors.green.shade900;
    final iconColor = isDark ? Colors.green.shade300 : Colors.green.shade700;

    final subtitle = [
      if (tune.type != null) tune.type!.name,
      if (tune.key != null && tune.key!.isNotEmpty) tune.key!,
    ].join(' · ');

    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(Icons.check_circle, color: iconColor),
        title: Text(tune.name, style: TextStyle(color: fg)),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, style: TextStyle(color: fg)),
        trailing: Text('In library', style: TextStyle(fontSize: 12, color: fg)),
        onTap: onTap,
      ),
    );
  }
}

/// An expandable result card. Collapsed it shows the tune's metadata; expanded
/// it renders the ABC, mounts the shared play button (with its tempo slider),
/// and offers a "Use this setting" action. Only one card is expanded at a time
/// (see [_TunePickerDialogState._expandedKey]).
class _RemoteResultCard extends ConsumerStatefulWidget {
  final RemoteTune tune;
  final bool expanded;
  final bool resolving;
  final VoidCallback onToggle;
  final VoidCallback onUse;

  const _RemoteResultCard({
    required this.tune,
    required this.expanded,
    required this.resolving,
    required this.onToggle,
    required this.onUse,
    super.key,
  });

  @override
  ConsumerState<_RemoteResultCard> createState() => _RemoteResultCardState();
}

class _RemoteResultCardState extends ConsumerState<_RemoteResultCard> {
  String? _svg;
  String? _renderedAbc;
  bool _rendering = false;

  @override
  void initState() {
    super.initState();
    if (widget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRender());
    }
  }

  @override
  void didUpdateWidget(_RemoteResultCard old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) _maybeRender();
  }

  Future<void> _maybeRender() async {
    final abc = widget.tune.abc;
    if (abc == null || abc.trim().isEmpty) return;
    if (_renderedAbc == abc && _svg != null) return;
    setState(() => _rendering = true);
    final svg = await ref.read(abcRendererProvider).render(abc);
    if (!mounted) return;
    setState(() {
      _svg = svg;
      _renderedAbc = abc;
      _rendering = false;
    });
  }

  String _subtitle() {
    final t = widget.tune;
    return [
      if (t.type != null) t.type!.name,
      if (t.key != null && t.key!.isNotEmpty) t.key!,
      if (t.date != null) relativeAge(t.date!),
      if (t.contributor != null && t.contributor!.isNotEmpty)
        'by ${t.contributor}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final tune = widget.tune;
    final subtitle = _subtitle();
    final abc = tune.abc;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.public, color: Colors.blueGrey),
            title: Text(tune.name),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: Icon(
              widget.expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: widget.onToggle,
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_rendering)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    AbcView(abc: abc, svg: _svg),
                  const SizedBox(height: 8),
                  AbcPlayButton(abc: abc),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      icon: widget.resolving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Use this setting'),
                      onPressed: widget.resolving ? null : widget.onUse,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CreateNewTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _CreateNewTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.add_circle_outline),
        title: Text('Create new tune "$name"'),
        onTap: onTap,
      ),
    );
  }
}
