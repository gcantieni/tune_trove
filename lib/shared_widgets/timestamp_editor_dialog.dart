import 'package:flutter/material.dart';

import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';

/// Dialog that edits link details (timestamps + performed key) for a
/// tune–recording pair. Returns `({double? start, double? end, String? performedKey})`
/// on save, or `null` if cancelled. All fields are optional.
class TimestampEditorDialog extends StatefulWidget {
  final double? initialStart;
  final double? initialEnd;
  final String? initialPerformedKey;

  const TimestampEditorDialog({
    this.initialStart,
    this.initialEnd,
    this.initialPerformedKey,
    super.key,
  });

  @override
  State<TimestampEditorDialog> createState() => _TimestampEditorDialogState();
}

class _TimestampEditorDialogState extends State<TimestampEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  String? _performedKey;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: widget.initialStart == null ? '' : formatTime(widget.initialStart),
    );
    _endController = TextEditingController(
      text: widget.initialEnd == null ? '' : formatTime(widget.initialEnd),
    );
    final initialKey = widget.initialPerformedKey;
    _performedKey = (initialKey == null || initialKey.isEmpty)
        ? null
        : normalizePickerKey(initialKey);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await showKeyPickerSheet(context, currentKey: _performedKey);
    // null = dismissed; empty string = explicit clear.
    if (result == null) return;
    setState(() => _performedKey = result.isEmpty ? null : result);
  }

  String? _validateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return parseTime(raw) == null ? 'Use m:ss.cc or seconds' : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop((
      start: parseTime(_startController.text),
      end: parseTime(_endController.text),
      performedKey: _performedKey,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link details'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _startController,
              decoration: const InputDecoration(
                labelText: 'Start',
                hintText: 'm:ss.cc (leave blank for none)',
              ),
              validator: _validateTime,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _endController,
              decoration: const InputDecoration(
                labelText: 'End',
                hintText: 'm:ss.cc (leave blank for none)',
              ),
              validator: _validateTime,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickKey,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Performed key'),
                child: Text(
                  _performedKey ?? 'Tap to set (leave blank for none)',
                  style: _performedKey != null
                      ? null
                      : TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

String formatTime(double? sec) {
  if (sec == null) return '—:—';
  final totalCs = (sec * 100).round();
  final m = totalCs ~/ 6000;
  final s = (totalCs % 6000) ~/ 100;
  final cs = totalCs % 100;
  return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
}

double? parseTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(':')) {
    final colonParts = s.split(':');
    if (colonParts.length != 2) return null;
    final m = int.tryParse(colonParts[0]);
    if (m == null || m < 0) return null;
    final secPart = colonParts[1];
    if (secPart.contains('.')) {
      final dotParts = secPart.split('.');
      if (dotParts.length != 2) return null;
      final sec = int.tryParse(dotParts[0]);
      final cs = int.tryParse(dotParts[1].padRight(2, '0').substring(0, 2));
      if (sec == null ||
          cs == null ||
          sec < 0 ||
          sec >= 60 ||
          cs < 0 ||
          cs > 99) {
        return null;
      }
      return m * 60 + sec + cs / 100.0;
    } else {
      final sec = int.tryParse(secPart);
      if (sec == null || sec < 0 || sec >= 60) return null;
      return (m * 60 + sec).toDouble();
    }
  }
  final n = double.tryParse(s);
  if (n == null || n < 0) return null;
  return n;
}
