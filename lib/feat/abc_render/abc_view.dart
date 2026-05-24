import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

double _ch(Color c, double Function(Color) channel) =>
    (channel(c) * 255.0).roundToDouble();

// Builds a ColorFilter that remaps black→onSurface and white→surface,
// so ABCjs notation matches the app's Material theme colours exactly.
ColorFilter _buildThemeFilter(ColorScheme cs) {
  final fg = cs.onSurface;
  final bg = cs.surface;
  final fgR = _ch(fg, (c) => c.r); final bgR = _ch(bg, (c) => c.r);
  final fgG = _ch(fg, (c) => c.g); final bgG = _ch(bg, (c) => c.g);
  final fgB = _ch(fg, (c) => c.b); final bgB = _ch(bg, (c) => c.b);
  return ColorFilter.matrix(<double>[
    (bgR - fgR) / 255.0,  0,                    0,                    0,  fgR,
    0,                    (bgG - fgG) / 255.0,  0,                    0,  fgG,
    0,                    0,                    (bgB - fgB) / 255.0,  0,  fgB,
    0,                    0,                    0,                    1,    0,
  ]);
}

Widget _maybeinvert(BuildContext context, Widget child) {
  if (Theme.of(context).brightness == Brightness.dark) {
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
class AbcView extends StatelessWidget {
  final String? abc;
  final String? svg;

  const AbcView({required this.abc, required this.svg, super.key});

  @override
  Widget build(BuildContext context) {
    final hasSvg = svg != null && svg!.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
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
            color: cs.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: _maybeinvert(
            context,
            SvgPicture.string(svg!, alignment: Alignment.topLeft),
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

class _AbcFullScreenPage extends StatelessWidget {
  final String svg;

  const _AbcFullScreenPage({required this.svg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 6.0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _maybeinvert(
                  context,
                  SvgPicture.string(svg, alignment: Alignment.topLeft),
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              icon: Icon(Icons.close, color: cs.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
