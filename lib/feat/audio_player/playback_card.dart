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
                const _LoopRangeSlider(),
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

  static const _thumbDiameter = 20.0;
  static const _trackHeight = 4.0;
  static const _horizontalMargin = 12.0;

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
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
    );
    final speedLabelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth =
                constraints.maxWidth - _horizontalMargin * 2 - _thumbDiameter;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: duration > 0
                  ? (details) {
                      setState(() {
                        _dragStart = details.localPosition;
                        _dragStartValue = _scrubValue ?? state.position;
                        _isDragging = true;
                        _multiplier = 1.0;
                      });
                    }
                  : null,
              onPanUpdate: duration > 0
                  ? (details) {
                      if (_dragStart == null || _dragStartValue == null) return;
                      final dx =
                          details.localPosition.dx - _dragStart!.dx;
                      final vertDist =
                          (details.localPosition.dy - _dragStart!.dy).abs();
                      final multiplier = _multiplierForVertical(vertDist);
                      final delta =
                          dx * multiplier * duration / effectiveWidth;
                      setState(() {
                        _multiplier = multiplier;
                        _scrubValue =
                            (_dragStartValue! + delta).clamp(0.0, duration);
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
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: 0.24),
                            borderRadius:
                                BorderRadius.circular(_trackHeight / 2),
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
                              borderRadius:
                                  BorderRadius.circular(_trackHeight / 2),
                            ),
                          ),
                        ),
                      // Thumb
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

class _LoopRangeSlider extends ConsumerWidget {
  const _LoopRangeSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioPlayerProvider);
    final duration = state.duration;
    if (duration <= 0) return const SizedBox.shrink();

    final tertiary = Theme.of(context).colorScheme.tertiary;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      fontSize: 11,
      color: tertiary,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tertiary,
            thumbColor: tertiary,
            inactiveTrackColor: tertiary.withValues(alpha: 0.24),
            overlayColor: tertiary.withValues(alpha: 0.12),
          ),
          child: RangeSlider(
            values: RangeValues(
              state.loopStart.clamp(0.0, duration),
              state.loopEnd.clamp(0.0, duration),
            ),
            max: duration,
            onChanged: (v) => ref
                .read(audioPlayerProvider.notifier)
                .setLoopBounds(v.start, v.end),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(state.loopStart), style: labelStyle),
              Text(_fmt(state.loopEnd), style: labelStyle),
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
