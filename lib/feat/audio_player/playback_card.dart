import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';

class PlaybackCard extends ConsumerWidget {
  final String trackUri;
  final String title;
  final Widget leadingIcon;

  const PlaybackCard({
    required this.trackUri,
    required this.title,
    required this.leadingIcon,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final isCurrent = playerState.trackUri == trackUri;
    final isPlaying = isCurrent && playerState.isPlaying;
    final duration = isCurrent ? playerState.duration : 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leadingIcon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.repeat,
                    size: 22,
                    color: (isCurrent && playerState.isLooping)
                        ? Theme.of(context).colorScheme.tertiary
                        : null,
                  ),
                  onPressed: notifier.toggleLoop,
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 36,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      notifier.pause();
                    } else if (isCurrent && playerState.isPaused) {
                      notifier.resume();
                    } else {
                      notifier.play(trackUri);
                    }
                  },
                ),
              ],
            ),
            if (isCurrent) ...[
              const SizedBox(height: 4),
              const _ScrubbingSlider(),
              if (playerState.isLooping && duration > 0) ...[
                const SizedBox(height: 8),
                const _ScrubbingRangeSlider(),
              ],
              const SizedBox(height: 8),
              const _SpeedSlider(),
            ],
          ],
        ),
      ),
    );
  }
}

/// The playback value a scrub should start from, given a touch at
/// [touchTrackX] (pixels from the start of the effective track).
///
/// Touching within [grabRadius] of the current thumb grabs it and keeps
/// [currentValue] (so a deliberate grab fine-tunes from where the playhead
/// already is). Touching elsewhere on the line snaps the playhead to the
/// touched position; the drag then moves relative from there.
@visibleForTesting
double scrubStartValue({
  required double touchTrackX,
  required double currentValue,
  required double effectiveWidth,
  required double duration,
  required double grabRadius,
}) {
  if (duration <= 0 || effectiveWidth <= 0) return currentValue;
  final currentThumbX = effectiveWidth * (currentValue / duration);
  if ((touchTrackX - currentThumbX).abs() <= grabRadius) return currentValue;
  final fraction = (touchTrackX / effectiveWidth).clamp(0.0, 1.0);
  return fraction * duration;
}

class _ScrubbingSlider extends ConsumerStatefulWidget {
  const _ScrubbingSlider();

  @override
  ConsumerState<_ScrubbingSlider> createState() => _ScrubbingSliderState();
}

class _ScrubbingSliderState extends ConsumerState<_ScrubbingSlider> {
  double? _scrubValue;
  Offset? _dragStart;
  double? _dragStartValue;
  bool _isDragging = false;
  double _multiplier = 1.0;
  String? _lastTrackUri;
  bool _hovered = false;

  static const _thumbDiameter = 20.0;
  static const _trackHeight = 4.0;
  static const _horizontalMargin = 12.0;
  static const _haloDiameter = 36.0;

  double _multiplierForVertical(double dist) {
    if (dist < 40) return 1.0;
    if (dist < 80) return 0.25;
    if (dist < 130) return 0.05;
    return 0.01;
  }

  String? _labelForMultiplier(double m) {
    if (m >= 1.0) return null;
    if (m >= 0.25) return 'Quarter Speed';
    if (m >= 0.05) return 'Fine';
    return 'Ultra-fine';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final duration = state.duration;

    if (state.trackUri != _lastTrackUri) {
      _lastTrackUri = state.trackUri;
      _scrubValue = null;
      _dragStart = null;
      _dragStartValue = null;
      _isDragging = false;
    }

    final position = duration > 0
        ? (_scrubValue ?? state.position).clamp(0.0, duration)
        : 0.0;
    final fraction = duration > 0 ? position / duration : 0.0;

    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11);
    final speedLabelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth =
                constraints.maxWidth - _horizontalMargin * 2 - _thumbDiameter;
            final thumbCenterX =
                _horizontalMargin +
                effectiveWidth * fraction +
                _thumbDiameter / 2;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) {
                final over =
                    (event.localPosition.dx - thumbCenterX).abs() <=
                    _thumbDiameter;
                if (over != _hovered) setState(() => _hovered = over);
              },
              onExit: (_) {
                if (_hovered) setState(() => _hovered = false);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: duration > 0
                    ? (details) {
                        // Snap the playhead to the touch position (unless the
                        // touch grabbed the thumb), then drag relative from there.
                        final touchTrackX =
                            details.localPosition.dx -
                            _horizontalMargin -
                            _thumbDiameter / 2;
                        final startValue = scrubStartValue(
                          touchTrackX: touchTrackX,
                          currentValue: _scrubValue ?? state.position,
                          effectiveWidth: effectiveWidth,
                          duration: duration,
                          grabRadius: _thumbDiameter,
                        );
                        setState(() {
                          _dragStart = details.localPosition;
                          _dragStartValue = startValue;
                          _scrubValue = startValue;
                          _isDragging = true;
                          _multiplier = 1.0;
                        });
                      }
                    : null,
                onPanUpdate: duration > 0
                    ? (details) {
                        if (_dragStart == null || _dragStartValue == null) {
                          return;
                        }
                        final dx = details.localPosition.dx - _dragStart!.dx;
                        final vertDist =
                            (details.localPosition.dy - _dragStart!.dy).abs();
                        final multiplier = _multiplierForVertical(vertDist);
                        final delta =
                            dx * multiplier * duration / effectiveWidth;
                        setState(() {
                          _multiplier = multiplier;
                          _scrubValue = (_dragStartValue! + delta).clamp(
                            0.0,
                            duration,
                          );
                        });
                      }
                    : null,
                onPanEnd: duration > 0
                    ? (_) {
                        if (_scrubValue != null) {
                          ref
                              .read(audioPlayerProvider.notifier)
                              .seek(_scrubValue!);
                        }
                        setState(() {
                          _isDragging = false;
                          _scrubValue = null;
                          _dragStart = null;
                          _dragStartValue = null;
                          _multiplier = 1.0;
                        });
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalMargin,
                    vertical: 16,
                  ),
                  child: SizedBox(
                    height: _thumbDiameter,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        // Inactive track
                        Positioned(
                          left: _thumbDiameter / 2,
                          right: _thumbDiameter / 2,
                          child: Container(
                            height: _trackHeight,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.24,
                              ),
                              borderRadius: BorderRadius.circular(
                                _trackHeight / 2,
                              ),
                            ),
                          ),
                        ),
                        // Active track
                        if (fraction > 0)
                          Positioned(
                            left: _thumbDiameter / 2,
                            child: Container(
                              width: effectiveWidth * fraction,
                              height: _trackHeight,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(
                                  _trackHeight / 2,
                                ),
                              ),
                            ),
                          ),
                        // Thumb (with hover/drag halo behind it)
                        if (_hovered || _isDragging)
                          Positioned(
                            left:
                                effectiveWidth * fraction -
                                (_haloDiameter - _thumbDiameter) / 2,
                            child: Container(
                              width: _haloDiameter,
                              height: _haloDiameter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary.withValues(alpha: 0.18),
                              ),
                            ),
                          ),
                        Positioned(
                          left: effectiveWidth * fraction,
                          child: Container(
                            width: _thumbDiameter,
                            height: _thumbDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Speed label — fixed height so layout doesn't jump
        SizedBox(
          height: 16,
          child: _isDragging && _multiplier < 1.0
              ? Center(
                  child: Text(
                    _labelForMultiplier(_multiplier) ?? '',
                    style: speedLabelStyle,
                  ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: labelStyle),
              Text(_fmt(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double s) {
    final totalCs = (s * 100).round();
    final m = totalCs ~/ 6000;
    final sec = (totalCs % 6000) ~/ 100;
    final cs = totalCs % 100;
    return '$m:${sec.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

enum _Thumb { start, end }

/// New `(loopStart, loopEnd)` when a loop thumb is snapped to [position]
/// (e.g. by double-tapping it to the current playback position). Clamps the
/// snapped edge so the two thumbs can never cross.
@visibleForTesting
(double, double) loopBoundsAfterSnap({
  required bool isStart,
  required double position,
  required double loopStart,
  required double loopEnd,
  required double duration,
}) {
  final pos = position.clamp(0.0, duration);
  if (isStart) {
    return (pos.clamp(0.0, loopEnd), loopEnd);
  }
  return (loopStart, pos.clamp(loopStart, duration));
}

class _ScrubbingRangeSlider extends ConsumerStatefulWidget {
  const _ScrubbingRangeSlider();

  @override
  ConsumerState<_ScrubbingRangeSlider> createState() =>
      _ScrubbingRangeSliderState();
}

class _ScrubbingRangeSliderState extends ConsumerState<_ScrubbingRangeSlider> {
  Offset? _dragStart;
  double? _dragStartValue;
  _Thumb? _activeThumb;
  _Thumb _lastThumb = _Thumb.end;
  double? _scrubValue;
  bool _isDragging = false;
  // True once a pan has travelled past the tap threshold. A mouse click on
  // macOS jitters enough to start a (zero-distance) pan; without this guard its
  // onPanEnd would commit the unchanged bound on the same pointer-up as the
  // double-tap snap, reverting the snap. Touch never trips this (larger slop).
  bool _panMoved = false;
  double _multiplier = 1.0;

  // Manual double-tap detection on a Listener (raw pointer events). We can't use
  // any tap-family recognizer on the GestureDetector: it joins the gesture arena
  // alongside the pan recognizer and stops pan from winning under a precise
  // (mouse) pointer on macOS, which makes the loop thumbs un-draggable. Raw
  // pointer events don't enter the arena, so we time the taps ourselves. We key
  // off pointer-up (not -down) with a movement check so a drag isn't mistaken
  // for a tap.
  DateTime? _lastTapTime;
  Offset? _downPosition;
  Offset? _lastTapPosition;

  // Which thumb the mouse is currently hovering (for the hover halo). Null when
  // the cursor isn't over either thumb.
  _Thumb? _hoveredThumb;

  static const _thumbDiameter = 20.0;
  static const _trackHeight = 4.0;
  static const _horizontalMargin = 12.0;
  static const _haloDiameter = 36.0;

  double _multiplierForVertical(double dist) {
    if (dist < 40) return 1.0;
    if (dist < 80) return 0.25;
    if (dist < 130) return 0.05;
    return 0.01;
  }

  String? _labelForMultiplier(double m) {
    if (m >= 1.0) return null;
    if (m >= 0.25) return 'Quarter Speed';
    if (m >= 0.05) return 'Fine';
    return 'Ultra-fine';
  }

  _Thumb _nearestThumb(double touchX, double startX, double endX) {
    final distToStart = (touchX - startX).abs();
    final distToEnd = (touchX - endX).abs();
    if (distToStart < distToEnd) return _Thumb.start;
    if (distToEnd < distToStart) return _Thumb.end;
    return _lastThumb;
  }

  Widget _thumbHalo(Color color) => Container(
    width: _haloDiameter,
    height: _haloDiameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.18),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final duration = state.duration;
    if (duration <= 0) return const SizedBox.shrink();

    final loopStart = state.loopStart.clamp(0.0, duration);
    final loopEnd = state.loopEnd.clamp(0.0, duration);

    final displayStart = (_isDragging && _activeThumb == _Thumb.start)
        ? (_scrubValue ?? loopStart)
        : loopStart;
    final displayEnd = (_isDragging && _activeThumb == _Thumb.end)
        ? (_scrubValue ?? loopEnd)
        : loopEnd;

    final startFraction = displayStart / duration;
    final endFraction = displayEnd / duration;

    final tertiary = Theme.of(context).colorScheme.tertiary;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
      color: tertiary,
    );
    final speedLabelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth =
                constraints.maxWidth - _horizontalMargin * 2 - _thumbDiameter;
            final startThumbX = effectiveWidth * startFraction;
            final endThumbX = effectiveWidth * endFraction;
            // Thumb centres in the slider's own coordinate space (the thumbs
            // sit inside a horizontal margin / Stack).
            final startCenterX =
                _horizontalMargin + startThumbX + _thumbDiameter / 2;
            final endCenterX =
                _horizontalMargin + endThumbX + _thumbDiameter / 2;

            // Double-tap detection lives on a Listener (raw pointer events that
            // don't enter the gesture arena) so it can't compete with the pan
            // recognizer. A tap-family recognizer on the same GestureDetector
            // blocks the pan from winning under a precise (mouse) pointer on
            // macOS, which made the loop thumbs un-draggable.
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) {
                final x = event.localPosition.dx;
                final distStart = (x - startCenterX).abs();
                final distEnd = (x - endCenterX).abs();
                _Thumb? over;
                if (distStart <= _thumbDiameter || distEnd <= _thumbDiameter) {
                  over = distStart <= distEnd ? _Thumb.start : _Thumb.end;
                }
                if (over != _hoveredThumb) {
                  setState(() => _hoveredThumb = over);
                }
              },
              onExit: (_) {
                if (_hoveredThumb != null) {
                  setState(() => _hoveredThumb = null);
                }
              },
              child: Listener(
                onPointerDown: (event) => _downPosition = event.localPosition,
                onPointerUp: (event) {
                  final down = _downPosition;
                  _downPosition = null;
                  if (down == null) return;
                  // A drag releases far from where it started — only a stationary
                  // press/release counts as a tap for double-tap purposes.
                  if ((event.localPosition - down).distance > kTouchSlop) {
                    _lastTapTime = null;
                    _lastTapPosition = null;
                    return;
                  }
                  final now = DateTime.now();
                  final lastTime = _lastTapTime;
                  final lastPos = _lastTapPosition;
                  final isDoubleTap =
                      lastTime != null &&
                      now.difference(lastTime) < kDoubleTapTimeout &&
                      lastPos != null &&
                      (event.localPosition - lastPos).distance < kDoubleTapSlop;
                  if (!isDoubleTap) {
                    _lastTapTime = now;
                    _lastTapPosition = event.localPosition;
                    return;
                  }
                  // Reset so a third tap starts a fresh sequence.
                  _lastTapTime = null;
                  _lastTapPosition = null;
                  final touchX = event.localPosition.dx - _horizontalMargin;
                  // Move the double-tapped loop thumb to the current playback
                  // position — a quick way to set a loop edge precisely without
                  // fine-dragging. Clamp so the two thumbs can't cross.
                  final thumb = _nearestThumb(
                    touchX,
                    startThumbX + _thumbDiameter / 2,
                    endThumbX + _thumbDiameter / 2,
                  );
                  final fresh = ref.read(audioPlayerProvider);
                  final (newStart, newEnd) = loopBoundsAfterSnap(
                    isStart: thumb == _Thumb.start,
                    position: fresh.position,
                    loopStart: fresh.loopStart.clamp(0.0, duration),
                    loopEnd: fresh.loopEnd.clamp(0.0, duration),
                    duration: duration,
                  );
                  ref
                      .read(audioPlayerProvider.notifier)
                      .setLoopBounds(newStart, newEnd);
                  setState(() => _lastThumb = thumb);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    // Subtract horizontal margin to get position within track area.
                    final touchX = details.localPosition.dx - _horizontalMargin;
                    final thumb = _nearestThumb(
                      touchX,
                      startThumbX + _thumbDiameter / 2,
                      endThumbX + _thumbDiameter / 2,
                    );
                    setState(() {
                      _dragStart = details.localPosition;
                      _dragStartValue = thumb == _Thumb.start
                          ? loopStart
                          : loopEnd;
                      _activeThumb = thumb;
                      _lastThumb = thumb;
                      _isDragging = true;
                      _panMoved = false;
                      _multiplier = 1.0;
                      _scrubValue = _dragStartValue;
                    });
                  },
                  onPanUpdate: (details) {
                    if (_dragStart == null ||
                        _dragStartValue == null ||
                        _activeThumb == null) {
                      return;
                    }
                    if ((details.localPosition - _dragStart!).distance >
                        kTouchSlop) {
                      _panMoved = true;
                    }
                    final dx = details.localPosition.dx - _dragStart!.dx;
                    final vertDist = (details.localPosition.dy - _dragStart!.dy)
                        .abs();
                    final multiplier = _multiplierForVertical(vertDist);
                    final delta = dx * multiplier * duration / effectiveWidth;
                    final raw = _dragStartValue! + delta;
                    // Prevent the two thumbs from crossing each other.
                    final clamped = _activeThumb == _Thumb.start
                        ? raw.clamp(0.0, displayEnd)
                        : raw.clamp(displayStart, duration);
                    setState(() {
                      _multiplier = multiplier;
                      _scrubValue = clamped;
                    });
                  },
                  onPanEnd: (_) {
                    // Only commit a real drag. A click that never moved past the
                    // tap threshold leaves the bound to the double-tap handler.
                    if (_panMoved &&
                        _scrubValue != null &&
                        _activeThumb != null) {
                      final notifier = ref.read(audioPlayerProvider.notifier);
                      final s = ref.read(audioPlayerProvider);
                      if (_activeThumb == _Thumb.start) {
                        notifier.setLoopBounds(
                          _scrubValue!,
                          s.loopEnd.clamp(0.0, duration),
                        );
                      } else {
                        notifier.setLoopBounds(
                          s.loopStart.clamp(0.0, duration),
                          _scrubValue!,
                        );
                      }
                    }
                    setState(() {
                      _isDragging = false;
                      _panMoved = false;
                      _scrubValue = null;
                      _dragStart = null;
                      _dragStartValue = null;
                      _activeThumb = null;
                      _multiplier = 1.0;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _horizontalMargin,
                      vertical: 16,
                    ),
                    child: SizedBox(
                      height: _thumbDiameter,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          // Inactive track (full width)
                          Positioned(
                            left: _thumbDiameter / 2,
                            right: _thumbDiameter / 2,
                            child: Container(
                              height: _trackHeight,
                              decoration: BoxDecoration(
                                color: tertiary.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(
                                  _trackHeight / 2,
                                ),
                              ),
                            ),
                          ),
                          // Active range between the two thumbs
                          Positioned(
                            left:
                                _thumbDiameter / 2 +
                                effectiveWidth * startFraction,
                            child: Container(
                              width:
                                  (effectiveWidth *
                                          (endFraction - startFraction))
                                      .clamp(0.0, double.infinity),
                              height: _trackHeight,
                              decoration: BoxDecoration(
                                color: tertiary,
                                borderRadius: BorderRadius.circular(
                                  _trackHeight / 2,
                                ),
                              ),
                            ),
                          ),
                          // Start thumb (with hover/drag halo behind it)
                          if (_hoveredThumb == _Thumb.start ||
                              (_isDragging && _activeThumb == _Thumb.start))
                            Positioned(
                              left:
                                  startThumbX -
                                  (_haloDiameter - _thumbDiameter) / 2,
                              child: _thumbHalo(tertiary),
                            ),
                          Positioned(
                            left: startThumbX,
                            child: Container(
                              width: _thumbDiameter,
                              height: _thumbDiameter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tertiary,
                              ),
                            ),
                          ),
                          // End thumb (with hover/drag halo behind it)
                          if (_hoveredThumb == _Thumb.end ||
                              (_isDragging && _activeThumb == _Thumb.end))
                            Positioned(
                              left:
                                  endThumbX -
                                  (_haloDiameter - _thumbDiameter) / 2,
                              child: _thumbHalo(tertiary),
                            ),
                          Positioned(
                            left: endThumbX,
                            child: Container(
                              width: _thumbDiameter,
                              height: _thumbDiameter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Speed label — fixed height so layout doesn't jump
        SizedBox(
          height: 16,
          child: _isDragging && _multiplier < 1.0
              ? Center(
                  child: Text(
                    _labelForMultiplier(_multiplier) ?? '',
                    style: speedLabelStyle,
                  ),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(displayStart), style: labelStyle),
              Text(_fmt(displayEnd), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double s) {
    final totalCs = (s * 100).round();
    final m = totalCs ~/ 6000;
    final sec = (totalCs % 6000) ~/ 100;
    final cs = totalCs % 100;
    return '$m:${sec.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

class _SpeedSlider extends ConsumerWidget {
  const _SpeedSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(audioPlayerProvider.select((s) => s.playbackRate));
    final pct = (rate * 100).round();
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11);
    final dimStyle = labelStyle?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
    );

    return Column(
      children: [
        Slider(
          value: rate,
          min: 0.5,
          max: 1.25,
          onChanged: (v) =>
              ref.read(audioPlayerProvider.notifier).setPlaybackRate(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text('50%', style: dimStyle),
              Expanded(
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
              Text('125%', style: dimStyle),
            ],
          ),
        ),
      ],
    );
  }
}
