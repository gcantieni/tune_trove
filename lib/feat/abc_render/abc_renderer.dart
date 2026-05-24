import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/abc_render/webview_abc_renderer.dart';

/// Renders ABC notation to an SVG string. The implementation is
/// deliberately hidden behind this interface so the abc_render module
/// can be swapped (or removed) in one place.
///
/// Returns the SVG markup on success, or null on any failure (offline
/// first-load, malformed ABC, abcjs error). Callers should fall back
/// to plaintext on null.
abstract class AbcRenderer {
  Future<String?> render(String abc);

  /// Frees the underlying resources. Safe to call multiple times.
  Future<void> dispose();

  /// Returns a widget that must be kept in the app widget tree (e.g. via
  /// [Offstage]) for the renderer to function. Returns null for
  /// implementations that do not require a widget anchor (e.g. process-based
  /// renderers on Linux).
  Widget? anchorWidget() => null;
}

final abcRendererProvider = Provider<AbcRenderer>((ref) {
  final renderer = WebViewAbcRenderer();
  ref.onDispose(renderer.dispose);
  return renderer;
});

/// Mounts the renderer's anchor widget in the app tree. Place once at the
/// app root wrapped in [Offstage] so it stays alive but is never painted.
class AbcRendererAnchor extends ConsumerWidget {
  const AbcRendererAnchor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchor = ref.watch(abcRendererProvider).anchorWidget();
    if (anchor == null) return const SizedBox.shrink();
    return Offstage(child: anchor);
  }
}
