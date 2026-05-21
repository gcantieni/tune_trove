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
              const _PlaybackSlider(),
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

class _PlaybackSlider extends ConsumerStatefulWidget {
  const _PlaybackSlider();

  @override
  ConsumerState<_PlaybackSlider> createState() => _PlaybackSliderState();
}

class _PlaybackSliderState extends ConsumerState<_PlaybackSlider> {
  double? _dragValue;
  String? _lastTrackUri;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final duration = state.duration;

    // Reset drag value when the active track changes.
    if (state.trackUri != _lastTrackUri) {
      _lastTrackUri = state.trackUri;
      _dragValue = null;
    }

    final position = _dragValue ?? state.position;
    final sliderValue = duration > 0 ? position.clamp(0.0, duration) : 0.0;
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11);

    return Column(
      children: [
        Slider(
          value: duration > 0 ? sliderValue : 0.0,
          max: duration > 0 ? duration : 1,
          onChanged: duration > 0
              ? (v) => setState(() => _dragValue = v)
              : null,
          onChangeEnd: duration > 0
              ? (v) {
                  ref.read(audioPlayerProvider.notifier).seek(v);
                  setState(() => _dragValue = null);
                }
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
    final sec = s.round();
    final m = sec ~/ 60;
    final r = (sec % 60).toString().padLeft(2, '0');
    return '$m:$r';
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
    final sec = s.round();
    final m = sec ~/ 60;
    final r = (sec % 60).toString().padLeft(2, '0');
    return '$m:$r';
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
