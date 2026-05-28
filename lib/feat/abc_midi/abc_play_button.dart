import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/abc_midi/abc_midi_player.dart';
import 'package:tune_trove/feat/abc_midi/abc_midi_state.dart';

/// Play button for the current tune's ABC. The control is actually an HTML
/// button rendered inside the player's WebView — see [AbcMidiPlayer] — so
/// taps register as WebKit gestures (required to unlock Web Audio).
class AbcPlayButton extends ConsumerStatefulWidget {
  final String? abc;
  const AbcPlayButton({required this.abc, super.key});

  @override
  ConsumerState<AbcPlayButton> createState() => _AbcPlayButtonState();
}

class _AbcPlayButtonState extends ConsumerState<AbcPlayButton> {
  static const double _width = 120;
  static const double _height = 40;
  Brightness? _lastBrightness;
  ColorScheme? _lastScheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(abcMidiPlayerProvider).setCurrentAbc(widget.abc);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    if (scheme != _lastScheme || brightness != _lastBrightness) {
      _lastScheme = scheme;
      _lastBrightness = brightness;
      ref.read(abcMidiPlayerProvider).setTheme(_themeVars(scheme, brightness));
    }
  }

  @override
  void didUpdateWidget(AbcPlayButton old) {
    super.didUpdateWidget(old);
    if (old.abc != widget.abc) {
      ref.read(abcMidiPlayerProvider).setCurrentAbc(widget.abc);
    }
  }

  Map<String, String> _themeVars(ColorScheme scheme, Brightness brightness) {
    String rgba(Color c, double a) =>
        // ignore: deprecated_member_use
        'rgba(${c.red}, ${c.green}, ${c.blue}, ${(a * c.opacity).toStringAsFixed(3)})';
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    return {
      'btn-fg': rgba(scheme.primary, 1),
      'btn-outline': rgba(scheme.outline, 1),
      'btn-hover': rgba(scheme.primary, 0.08),
      'btn-active': rgba(scheme.primary, 0.16),
      'scaffold-bg': rgba(scaffoldBg, 1),
    };
  }

  @override
  void dispose() {
    // Clear the active tune so a stale tap in the WebView can't play after
    // the user navigated away. Audio that's already playing keeps going —
    // the user can stop it from the button on whatever tune they revisit.
    ref.read(abcMidiPlayerProvider).setCurrentAbc(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.abc == null || widget.abc!.trim().isEmpty;
    if (disabled) {
      return SizedBox(
        width: _width,
        height: _height,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Play'),
          onPressed: null,
        ),
      );
    }

    final player = ref.watch(abcMidiPlayerProvider);
    return StreamBuilder<AbcMidiState>(
      stream: player.stateStream,
      initialData: player.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AbcMidiState();
        return Row(
          children: [
            SizedBox(
              width: _width,
              height: _height,
              child: player.viewWidget(),
            ),
            if (state.status == AbcMidiStatus.error) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.message ?? 'Playback error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
