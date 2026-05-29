import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tune_trove/feat/settings/settings_providers.dart';

double _ch(Color c, double Function(Color) channel) =>
    (channel(c) * 255.0).roundToDouble();

// Builds a ColorFilter that remaps black→onSurface and white→surface,
// so ABCjs notation matches the app's Material theme colours exactly.
ColorFilter _buildThemeFilter(ColorScheme cs) {
  final fg = cs.onSurface;
  final bg = cs.surface;
  final fgR = _ch(fg, (c) => c.r);
  final bgR = _ch(bg, (c) => c.r);
  final fgG = _ch(fg, (c) => c.g);
  final bgG = _ch(bg, (c) => c.g);
  final fgB = _ch(fg, (c) => c.b);
  final bgB = _ch(bg, (c) => c.b);
  return ColorFilter.matrix(<double>[
    (bgR - fgR) / 255.0,
    0,
    0,
    0,
    fgR,
    0,
    (bgG - fgG) / 255.0,
    0,
    0,
    fgG,
    0,
    0,
    (bgB - fgB) / 255.0,
    0,
    fgB,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// Whether the theme-matching color filter should be applied: only in dark
/// mode and only when the user has left inversion enabled. When false, the
/// notation renders in its native black-on-transparent form and therefore
/// needs a white backing (see [_notationBackground]).
bool _shouldInvert(BuildContext context, bool invert) =>
    invert && Theme.of(context).brightness == Brightness.dark;

/// Background to place behind the SVG. When inverting we blend into the dark
/// theme surface; otherwise we force white so the black notation stays
/// readable (traditional black-on-white sheet music).
Color _notationBackground(BuildContext context, bool inverted) =>
    inverted ? Theme.of(context).colorScheme.surface : Colors.white;

Widget _maybeInvert(
  BuildContext context, {
  required bool inverted,
  required Widget child,
}) {
  if (inverted) {
    return ColorFiltered(
      colorFilter: _buildThemeFilter(Theme.of(context).colorScheme),
      child: child,
    );
  }
  return child;
}

/// Renders cached ABC sheet music if [svg] is available; otherwise
/// falls back to the plaintext block. Kept tiny and self-contained so
/// callers don't need to know about flutter_svg or the renderer.
class AbcView extends ConsumerWidget {
  final String? abc;
  final String? svg;

  const AbcView({required this.abc, required this.svg, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSvg = svg != null && svg!.isNotEmpty;
    final invert = ref.watch(invertNotationInDarkModeProvider).value ?? true;
    final inverted = _shouldInvert(context, invert);
    if (hasSvg) {
      return GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => _AbcFullScreenPage(svg: svg!),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _notationBackground(context, inverted),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _maybeInvert(
            context,
            inverted: inverted,
            child: SvgPicture.string(svg!, alignment: Alignment.topLeft),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        (abc == null || abc!.isEmpty) ? '—' : abc!,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}

class _AbcFullScreenPage extends ConsumerWidget {
  final String svg;

  const _AbcFullScreenPage({required this.svg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final invert = ref.watch(invertNotationInDarkModeProvider).value ?? true;
    final inverted = _shouldInvert(context, invert);
    return Scaffold(
      backgroundColor: _notationBackground(context, inverted),
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 6.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _maybeInvert(
                  context,
                  inverted: inverted,
                  child: SvgPicture.string(svg, alignment: Alignment.topLeft),
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: Icon(
                Icons.close,
                color: inverted ? cs.onSurface : Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
