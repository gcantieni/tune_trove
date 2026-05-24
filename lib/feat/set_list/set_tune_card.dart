import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/model/accessors/set_tune_dao.dart';
import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';

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
    final result = await showKeyPickerSheet(
      context,
      currentKey: currentKey,
      defaultKey: widget.entry.tune.key,
      clearLabel: 'Clear override',
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
