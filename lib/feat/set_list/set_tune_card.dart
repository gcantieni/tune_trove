import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/model/accessors/set_tune_dao.dart';

const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

// Displayed in the wheel; stored value is the parallel entry in _accidentalValues.
const _accidentalSymbols = ['♯', '♮', '♭'];
const _accidentalValues = ['#', '', 'b']; // '' = natural

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

String _buildKey(int letterIdx, int accIdx, int modeIdx) {
  final letter = _letters[letterIdx];
  final acc = _accidentalValues[accIdx];
  final suffix = _modeSuffixes[modeIdx];
  return '$letter$acc$suffix';
}

// Parses a stored key string, e.g. "ADor" → (0, 1, 1), "Bb" → (1, 2, 0).
// Compatible with keys stored by the old two-wheel format.
(int, int, int) _parseKey(String key) {
  if (key.isEmpty) return (_letters.indexOf('D'), 1, 0);

  final letterIdx = _letters.indexOf(key[0]);
  final safeLetterIdx = letterIdx == -1 ? _letters.indexOf('D') : letterIdx;

  var rest = key.substring(1);

  // '#' or lowercase 'b' as accidental (mode suffixes all start uppercase or 'm').
  int accIdx = 1; // natural
  if (rest.startsWith('#')) {
    accIdx = 0;
    rest = rest.substring(1);
  } else if (rest.startsWith('b') &&
      (rest.length == 1 || rest[1] != rest[1].toLowerCase())) {
    // 'b' followed by uppercase or end-of-string → flat accidental
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

class SetTuneCard extends StatefulWidget {
  const SetTuneCard({
    required this.entry,
    required this.index,
    required this.onDelete,
    required this.onKeyChanged,
    super.key,
  });

  final SetTuneEntry entry;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<String?> onKeyChanged;

  @override
  State<SetTuneCard> createState() => _SetTuneCardState();
}

class _SetTuneCardState extends State<SetTuneCard>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 80.0;
  // Matches Flutter Material 3 Card defaults.
  static const _cardMargin = 4.0;
  static const _cardRadius = Radius.circular(12);

  late final AnimationController _controller;
  double _dragStartDx = 0;
  double _valueAtDragStart = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isOpen => _controller.value > 0.5;

  void _onHorizontalDragStart(DragStartDetails d) {
    _controller.stop();
    _dragStartDx = d.globalPosition.dx;
    _valueAtDragStart = _controller.value;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    final delta = d.globalPosition.dx - _dragStartDx;
    _controller.value = (_valueAtDragStart - delta / _actionWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -300) {
      _controller.animateTo(1.0);
    } else if (v > 300) {
      _controller.animateTo(0.0);
    } else if (_controller.value >= 0.5) {
      _controller.animateTo(1.0);
    } else {
      _controller.animateTo(0.0);
    }
  }

  void _close() => _controller.animateTo(0.0);

  Future<void> _showKeyPicker(BuildContext context) async {
    final currentKey = widget.entry.link.key ?? widget.entry.tune.key;
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _KeyPickerSheet(
        currentKey: currentKey,
        tuneDefaultKey: widget.entry.tune.key,
      ),
    );
    if (result != null) {
      widget.onKeyChanged(result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveKey = widget.entry.link.key ?? widget.entry.tune.key;
    final hasOverride = widget.entry.link.key != null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: ClipRect(
            child: Stack(
              children: [
                // Delete strip inset to match the Card's margin + right-side radius.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(_cardMargin),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: _cardRadius,
                          bottomRight: _cardRadius,
                        ),
                        child: SizedBox(
                          width: _actionWidth,
                          child: GestureDetector(
                            onTap: widget.onDelete,
                            child: const ColoredBox(
                              color: Colors.red,
                              child: Center(
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Card slides left to reveal the delete strip.
                Transform.translate(
                  offset: Offset(-_controller.value * _actionWidth, 0),
                  child: Card(
                    child: ListTile(
                      title: Text(widget.entry.tune.name),
                      subtitle: effectiveKey != null && effectiveKey.isNotEmpty
                          ? GestureDetector(
                              onTap: () => _showKeyPicker(context),
                              child: _KeyChip(
                                label: effectiveKey,
                                isOverride: hasOverride,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _showKeyPicker(context),
                              child: Text(
                                'Set key…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                      // Drag handle — immediate drag, no long-press needed.
                      trailing: ReorderableDragStartListener(
                        index: widget.index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      onTap: _isOpen
                          ? _close
                          : () => context.push(
                              '/tune_list/${widget.entry.tune.id}',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.isOverride});

  final String label;
  final bool isOverride;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverride ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isOverride ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _KeyPickerSheet extends StatefulWidget {
  const _KeyPickerSheet({
    required this.currentKey,
    required this.tuneDefaultKey,
  });

  final String? currentKey;
  final String? tuneDefaultKey;

  @override
  State<_KeyPickerSheet> createState() => _KeyPickerSheetState();
}

class _KeyPickerSheetState extends State<_KeyPickerSheet> {
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
      final parsed = _parseKey(key);
      _letterIdx = parsed.$1;
      _accIdx = parsed.$2;
      _modeIdx = parsed.$3;
    } else {
      _letterIdx = _letters.indexOf('D');
      _accIdx = 1; // natural
      _modeIdx = 0; // Major
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

  String get _preview => _buildKey(_letterIdx, _accIdx, _modeIdx);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOverride = widget.currentKey != null;

    // showCupertinoModalPopup provides no surface — wrap in Material so that
    // Theme, ink effects, and text styles all resolve correctly.
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
                  if (widget.tuneDefaultKey != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· default: ${widget.tuneDefaultKey}',
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
                  // Letter wheel — A B C D E F G
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
                  // Accidental wheel — ♯ ♮ ♭
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
                  // Mode wheel — Major Dorian … Locrian
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
                  if (hasOverride)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: const Text('Clear override'),
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
