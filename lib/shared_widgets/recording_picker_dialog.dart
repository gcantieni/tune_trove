import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/recordings_provider.dart';

const _debounceDelay = Duration(milliseconds: 100);

/// A search-driven recording picker. Lists recordings already in the
/// library and lets the caller link the chosen one. When the typed
/// query looks like a URL, the dialog swaps to an inline create form
/// so the user can name the recording in context.
class RecordingPickerDialog extends ConsumerStatefulWidget {
  final String title;
  final void Function(Recording recording) onPicked;
  final void Function(RecordingsCompanion recording) onCreateNew;

  const RecordingPickerDialog({
    required this.title,
    required this.onPicked,
    required this.onCreateNew,
    super.key,
  });

  @override
  ConsumerState<RecordingPickerDialog> createState() =>
      _RecordingPickerDialogState();
}

class _RecordingPickerDialogState extends ConsumerState<RecordingPickerDialog> {
  final _searchController = TextEditingController();
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  bool _inCreateMode = false;
  String? _createUrl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(
        () => _debouncedQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  void _pick(Recording r) {
    Navigator.of(context).pop();
    widget.onPicked(r);
  }

  void _enterCreateMode(String url) {
    setState(() {
      _inCreateMode = true;
      _createUrl = url;
    });
  }

  String? _pendingName;

  void _enterCreateModeByName(String name) {
    setState(() {
      _inCreateMode = true;
      _createUrl = null;
      _pendingName = name;
    });
  }

  void _cancelCreate() {
    setState(() {
      _inCreateMode = false;
      _createUrl = null;
      _pendingName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _inCreateMode ? _buildCreateForm() : _buildSearchView(),
        ),
      ),
    );
  }

  Widget _buildSearchView() {
    final query = _debouncedQuery;
    final recordingsAsync = ref.watch(allRecordingsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Recording name or URL',
            hintText: 'Search, type a name, or paste a URL…',
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: recordingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('Error: $e'),
            data: (recordings) => _buildSuggestions(query, recordings),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions(String query, List<Recording> all) {
    final raw = _searchController.text.trim();
    final matches = query.isEmpty
        ? all
        : all.where((r) => r.name.toLowerCase().contains(query)).toList();
    final urlToCreate = looksLikeUrl(raw) ? raw : null;
    final nameToCreate = (raw.isNotEmpty && !looksLikeUrl(raw)) ? raw : null;

    if (matches.isEmpty && urlToCreate == null && nameToCreate == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          query.isEmpty
              ? 'No recordings yet — type a name or paste a URL to add one.'
              : 'No matching recordings — create one with this name or paste a URL.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        for (final r in matches)
          _RecordingTile(recording: r, onTap: () => _pick(r)),
        if (urlToCreate != null) ...[
          if (matches.isNotEmpty) const SizedBox(height: 8),
          _CreateRecordingFromUrlTile(
            url: urlToCreate,
            onTap: () => _enterCreateMode(urlToCreate),
          ),
        ],
        if (nameToCreate != null) ...[
          if (matches.isNotEmpty) const SizedBox(height: 8),
          _CreateRecordingByNameTile(
            name: nameToCreate,
            onTap: () => _enterCreateModeByName(nameToCreate),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New recording',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          RecordingFormWidget(
            key: ValueKey(_createUrl ?? _pendingName ?? ''),
            initialUrl: _createUrl,
            initialName: _pendingName,
            submitLabel: 'Create and link',
            onCancel: _cancelCreate,
            onSave: (companion) async {
              Navigator.of(context).pop();
              widget.onCreateNew(companion);
            },
          ),
        ],
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  final Recording recording;
  final VoidCallback onTap;
  const _RecordingTile({required this.recording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final performers = recording.performers;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.album),
        title: Text(recording.name),
        subtitle: (performers == null || performers.isEmpty)
            ? null
            : Text(performers),
        onTap: onTap,
      ),
    );
  }
}

class _CreateRecordingFromUrlTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _CreateRecordingFromUrlTile({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.add_link),
        title: const Text('Create new recording'),
        subtitle: Text(
          url,
          style: const TextStyle(fontFamily: 'monospace'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _CreateRecordingByNameTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _CreateRecordingByNameTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: const Icon(Icons.add),
        title: Text('Create recording named "$name"'),
        onTap: onTap,
      ),
    );
  }
}
