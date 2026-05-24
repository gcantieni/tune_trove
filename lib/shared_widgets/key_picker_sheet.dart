import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

const _accidentalSymbols = ['♯', '♮', '♭'];
const _accidentalValues = ['#', '', 'b'];

const _modes = [
  'Major',
  'Dorian',
  'Phrygian',
  'Lydian',
  'Mixolydian',
  'Minor',
  'Locrian',
];
const _modeSuffixes = ['', 'Dor', 'Phr', 'Lyd', 'Mix', 'm', 'Loc'];

// TheSession JSON uses lowercase mode suffixes; "maj" has no picker suffix.
const _sessionModeSuffixMap = {
  'maj': '',
  'min': 'm',
  'dor': 'Dor',
  'mix': 'Mix',
  'phr': 'Phr',
  'lyd': 'Lyd',
  'loc': 'Loc',
};

/// Converts a TheSession-format key string to picker format.
/// "Ador" → "ADor", "Amaj" → "A", "Amin" → "Am", "Gmix" → "GMix".
/// Already-normalized strings are returned unchanged.
String normalizePickerKey(String key) {
  if (key.length < 2) return key;

  final letter = key[0].toUpperCase();
  var rest = key.substring(1);

  String acc = '';
  if (rest.startsWith('#')) {
    acc = '#';
    rest = rest.substring(1);
  } else if (rest.startsWith('b') &&
      (rest.length == 1 || rest[1] != rest[1].toLowerCase())) {
    acc = 'b';
    rest = rest.substring(1);
  }

  final suffix =
      _sessionModeSuffixMap[rest.toLowerCase()] ??
      (_modeSuffixes.contains(rest) ? rest : rest);
  return '$letter$acc$suffix';
}

String buildPickerKey(int letterIdx, int accIdx, int modeIdx) {
  final letter = _letters[letterIdx];
  final acc = _accidentalValues[accIdx];
  final suffix = _modeSuffixes[modeIdx];
  return '$letter$acc$suffix';
}

// Parses a stored key string, e.g. "ADor" → (0, 1, 1), "Bb" → (1, 2, 0).
// Also accepts TheSession format, e.g. "Ador", "Amaj".
(int, int, int) parsePickerKey(String key) {
  if (key.isEmpty) return (_letters.indexOf('D'), 1, 0);
  // ignore: parameter_assignments
  key = normalizePickerKey(key);

  final letterIdx = _letters.indexOf(key[0]);
  final safeLetterIdx = letterIdx == -1 ? _letters.indexOf('D') : letterIdx;

  var rest = key.substring(1);

  int accIdx = 1; // natural
  if (rest.startsWith('#')) {
    accIdx = 0;
    rest = rest.substring(1);
  } else if (rest.startsWith('b') &&
      (rest.length == 1 || rest[1] != rest[1].toLowerCase())) {
    accIdx = 2;
    rest = rest.substring(1);
  }

  var modeIdx = 0;
  for (var i = _modeSuffixes.length - 1; i >= 1; i--) {
    if (rest == _modeSuffixes[i]) {
      modeIdx = i;
      break;
    }
  }
  return (safeLetterIdx, accIdx, modeIdx);
}

/// Shows the key picker sheet and returns the selected key string,
/// an empty string to clear, or null if cancelled.
Future<String?> showKeyPickerSheet(
  BuildContext context, {
  String? currentKey,
  String? defaultKey,
  String clearLabel = 'Clear',
}) {
  return showCupertinoModalPopup<String?>(
    context: context,
    builder: (_) => KeyPickerSheet(
      currentKey: currentKey,
      defaultKey: defaultKey,
      clearLabel: clearLabel,
    ),
  );
}

class KeyPickerSheet extends StatefulWidget {
  const KeyPickerSheet({
    required this.currentKey,
    this.defaultKey,
    this.clearLabel = 'Clear',
    super.key,
  });

  final String? currentKey;
  final String? defaultKey;
  final String clearLabel;

  @override
  State<KeyPickerSheet> createState() => _KeyPickerSheetState();
}

class _KeyPickerSheetState extends State<KeyPickerSheet> {
  late int _letterIdx;
  late int _accIdx;
  late int _modeIdx;
  late final FixedExtentScrollController _letterCtrl;
  late final FixedExtentScrollController _accCtrl;
  late final FixedExtentScrollController _modeCtrl;

  @override
  void initState() {
    super.initState();
    final key = widget.currentKey;
    if (key != null && key.isNotEmpty) {
      final parsed = parsePickerKey(key);
      _letterIdx = parsed.$1;
      _accIdx = parsed.$2;
      _modeIdx = parsed.$3;
    } else {
      _letterIdx = _letters.indexOf('D');
      _accIdx = 1;
      _modeIdx = 0;
    }
    _letterCtrl = FixedExtentScrollController(initialItem: _letterIdx);
    _accCtrl = FixedExtentScrollController(initialItem: _accIdx);
    _modeCtrl = FixedExtentScrollController(initialItem: _modeIdx);
  }

  @override
  void dispose() {
    _letterCtrl.dispose();
    _accCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  String get _preview => buildPickerKey(_letterIdx, _accIdx, _modeIdx);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canClear = widget.currentKey != null;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Key', style: theme.textTheme.titleMedium),
                  if (widget.defaultKey != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· default: ${widget.defaultKey}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Three picker wheels: letter | accidental | mode
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      backgroundColor: Colors.transparent,
                      scrollController: _letterCtrl,
                      itemExtent: 36,
                      onSelectedItemChanged: (i) =>
                          setState(() => _letterIdx = i),
                      children: [
                        for (final l in _letters)
                          Center(
                            child: Text(l, style: theme.textTheme.titleMedium),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      backgroundColor: Colors.transparent,
                      scrollController: _accCtrl,
                      itemExtent: 36,
                      onSelectedItemChanged: (i) => setState(() => _accIdx = i),
                      children: [
                        for (final s in _accidentalSymbols)
                          Center(
                            child: Text(s, style: theme.textTheme.titleLarge),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: CupertinoPicker(
                      backgroundColor: Colors.transparent,
                      scrollController: _modeCtrl,
                      itemExtent: 36,
                      onSelectedItemChanged: (i) =>
                          setState(() => _modeIdx = i),
                      children: [
                        for (final m in _modes)
                          Center(
                            child: Text(m, style: theme.textTheme.titleMedium),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Preview
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _preview,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (canClear)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(widget.clearLabel),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_preview),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
