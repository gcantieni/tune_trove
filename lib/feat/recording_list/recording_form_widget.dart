import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tune_trove/feat/recording_list/apple_music_search_delegate.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';

const _titleFetchTimeout = Duration(seconds: 5);

/// Treat as a URL anything Uri.parse accepts that has a non-empty scheme,
/// e.g. `https://…`, `spotify:…`, `app-data:…`.
bool looksLikeUrl(String s) {
  if (s.isEmpty) return false;
  final uri = Uri.tryParse(s);
  return uri != null && uri.hasScheme && uri.scheme.isNotEmpty;
}

/// Best-effort scrape of an http(s) page title. Prefers OpenGraph `og:title`,
/// falls back to `<title>`. Returns null on any failure.
Future<String?> _fetchPageTitle(Uri uri) async {
  try {
    final response = await http
        .get(
          uri,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (compatible; tuneTrove/1.0; +https://tuneTrove.app)',
          },
        )
        .timeout(_titleFetchTimeout);
    if (response.statusCode != 200) return null;
    final document = html_parser.parse(response.body);
    final og = document
        .querySelector('meta[property="og:title"]')
        ?.attributes['content']
        ?.trim();
    if (og != null && og.isNotEmpty) return og;
    final title = document.querySelector('title')?.text.trim();
    if (title != null && title.isNotEmpty) return title;
    return null;
  } catch (_) {
    return null;
  }
}

class RecordingFormWidget extends ConsumerStatefulWidget {
  /// Called after the form is submitted. When null the form uses default
  /// behavior: inserts the recording into the DB and shows a snackbar.
  final Future<void> Function(RecordingsCompanion)? onSave;

  /// Called when the user taps the "Back" / cancel button. When null no
  /// cancel button is shown.
  final VoidCallback? onCancel;

  /// Label for the submit button.
  final String submitLabel;

  /// Pre-fills the URL field and triggers a title fetch on open.
  final String? initialUrl;

  /// Pre-fills the Name field on open.
  final String? initialName;

  /// Called after a successful default save (when [onSave] is null).
  final VoidCallback? onSubmitted;

  const RecordingFormWidget({
    super.key,
    this.onSave,
    this.onCancel,
    this.submitLabel = 'Save recording',
    this.initialUrl,
    this.initialName,
    this.onSubmitted,
  });

  @override
  ConsumerState<RecordingFormWidget> createState() =>
      _RecordingFormWidgetState();
}

class _RecordingFormWidgetState extends ConsumerState<RecordingFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _performersController = TextEditingController();
  bool _pickingFile = false;
  bool _fetchingTitle = false;
  int _fetchSeq = 0;
  String _lastFetchedUrl = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _maybeFetchTitle(widget.initialUrl!);
    }
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _fetchSeq++;
    _nameController.dispose();
    _urlController.dispose();
    _performersController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url == _lastFetchedUrl) return;
    _lastFetchedUrl = url;
    _maybeFetchTitle(url);
  }

  Future<void> _maybeFetchTitle(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (uri.scheme != 'http' && uri.scheme != 'https') return;

    final mySeq = ++_fetchSeq;
    setState(() => _fetchingTitle = true);

    final title = await _fetchPageTitle(uri);

    if (!mounted || mySeq != _fetchSeq) return;
    setState(() => _fetchingTitle = false);
    if (title != null && title.isNotEmpty && _nameController.text.isEmpty) {
      _nameController.text = title;
    }
  }

  Future<void> _searchAppleMusic(BuildContext context) async {
    final result = await showSearch(
      context: context,
      delegate: AppleMusicSearchDelegate(ref),
    );
    if (result == null) return;
    _nameController.text = '${result.title} – ${result.artistName}';
    _urlController.text = result.toRecordingUrl();
    _performersController.text = result.artistName;
  }

  Future<void> _pickLocalFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final sourcePath = picked.path;
      if (sourcePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File is not available locally — download it first.',
              ),
            ),
          );
        }
        return;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final destDir = Directory(p.join(docsDir.path, 'audio_recordings'));
      await destDir.create(recursive: true);

      final filename = _uniqueFilename(destDir, picked.name);
      final destFile = await File(
        sourcePath,
      ).copy(p.join(destDir.path, filename));

      if (!mounted) return;
      _urlController.text = 'file://${destFile.path}';
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = p.basenameWithoutExtension(filename);
      }
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  String _uniqueFilename(Directory dir, String name) {
    final ext = p.extension(name);
    final base = p.basenameWithoutExtension(name);
    var candidate = name;
    var counter = 2;
    while (File(p.join(dir.path, candidate)).existsSync()) {
      candidate = '${base}_$counter$ext';
      counter++;
    }
    return candidate;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final performers = _performersController.text.trim();
    final companion = RecordingsCompanion.insert(
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      createdAt: DateTime.now(),
      performers: drift.Value(performers.isEmpty ? null : performers),
    );

    if (widget.onSave != null) {
      await widget.onSave!(companion);
      return;
    }

    // Default behavior: insert into DB and show a snackbar.
    await ref.read(databaseProvider).recordingDao.insertRecording(companion);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"${_nameController.text}" saved!')));

    _formKey.currentState!.reset();
    _nameController.clear();
    _urlController.clear();
    _performersController.clear();

    widget.onSubmitted?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              suffixIcon: _fetchingTitle
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              helperText: _fetchingTitle ? 'Fetching page title…' : null,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://… or spotify:…',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.library_music, size: 18),
                  label: const Text('Search Apple Music'),
                  onPressed: () => _searchAppleMusic(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: _pickingFile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.audio_file_outlined, size: 18),
                  label: const Text('Local File'),
                  onPressed: _pickingFile ? null : _pickLocalFile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _performersController,
            decoration: const InputDecoration(labelText: 'Performers'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: widget.onCancel != null
                ? MainAxisAlignment.end
                : MainAxisAlignment.center,
            children: [
              if (widget.onCancel != null) ...[
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton(
                onPressed: _submit,
                child: Text(widget.submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
