import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/tune_source.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
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

    return Dialog(
      child: SizedBox(
        width: 600,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tune name',
                  hintText: 'Type to search…',
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
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
    return ListView(
      shrinkWrap: true,
      children: [
        if (matchingLocal.isNotEmpty) ...[
          const _SectionHeader('In your library'),
          for (final t in matchingLocal)
            _LibraryTuneTile(tune: t, onTap: () => _pickLibrary(t)),
        ],
        for (final entry in remoteResults.entries) ...[
          if (matchingLocal.isNotEmpty || entry.key != remoteResults.keys.first)
            const SizedBox(height: 8),
          _SectionHeader('From ${entry.key}'),
          for (final tune in _dedupedResults(
            entry.value,
            entry.key,
            localTsIds,
          ))
            _RemoteTuneTile(
              tune: tune,
              resolving: _resolvingTune == tune,
              onTap: () => _pickRemote(tune),
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

  List<RemoteTune> _dedupedResults(
    List<RemoteTune> results,
    String sourceName,
    Set<int> localTsIds,
  ) {
    if (sourceName == 'thesession.org') {
      return results
          .where(
            (t) =>
                t.sourceId == null ||
                !localTsIds.contains(int.tryParse(t.sourceId!)),
          )
          .take(20)
          .toList();
    }
    return results.take(20).toList();
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

class _RemoteTuneTile extends StatelessWidget {
  final RemoteTune tune;
  final bool resolving;
  final VoidCallback onTap;
  const _RemoteTuneTile({
    required this.tune,
    required this.resolving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = tune.type?.name;
    final key = tune.key;
    final subtitle = [
      if (type != null) type,
      if (key != null && key.isNotEmpty) key,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.public, color: Colors.blueGrey),
        title: Text(tune.name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: resolving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                tune.sourceName,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
        onTap: resolving ? null : onTap,
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
