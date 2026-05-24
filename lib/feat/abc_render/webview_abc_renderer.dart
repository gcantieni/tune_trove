import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView-backed renderer that hosts `assets/abcjs/render.html` and calls
/// `window.renderAbcToSvg(abc)` via JS evaluation to convert ABC notation to
/// an SVG string.
///
/// Lifecycle: the [WebViewController] is created immediately; the underlying
/// platform WebView spins up when [anchorWidget] is mounted in the tree.
/// Concurrent [render] calls are serialized because abcjs writes to a single
/// shared DOM div.
class WebViewAbcRenderer implements AbcRenderer {
  late final WebViewController _controller;
  Completer<void>? _ready;
  Future<String?>? _inFlight;

  WebViewAbcRenderer() {
    _ready = Completer<void>();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (_ready != null && !_ready!.isCompleted) _ready!.complete();
          },
          onWebResourceError: (WebResourceError error) {
            if (_ready != null && !_ready!.isCompleted) {
              _ready!.completeError(error);
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/abcjs/render.html');
  }

  /// A 1×1 [WebViewWidget] that must be kept in the app widget tree (via
  /// [Offstage]) for the underlying platform WebView to remain alive.
  @override
  Widget anchorWidget() => SizedBox(
    width: 1,
    height: 1,
    child: WebViewWidget(controller: _controller),
  );

  @override
  Future<String?> render(String abc) async {
    if (abc.trim().isEmpty) return null;
    // Serialize: abcjs writes into a single shared <div>.
    final previous = _inFlight;
    final completer = Completer<String?>();
    _inFlight = completer.future;
    try {
      if (previous != null) await previous;
      // Retry the asset load if a previous attempt failed.
      if (_ready == null) {
        _ready = Completer<void>();
        unawaited(_controller.loadFlutterAsset('assets/abcjs/render.html'));
      }
      await _ready!.future;
      final encoded = _jsonEncodeString(abc);
      final result = await _controller.runJavaScriptReturningResult(
        'window.renderAbcToSvg($encoded);',
      );
      final svg = _parseSvgResult(result);
      completer.complete(svg);
      return svg;
    } catch (_) {
      // Allow a retry on the next render call.
      _ready = null;
      completer.complete(null);
      return null;
    } finally {
      if (identical(_inFlight, completer.future)) _inFlight = null;
    }
  }

  @override
  Future<void> dispose() async {}
}

/// Handles platform differences in [WebViewController.runJavaScriptReturningResult]:
/// Android JSON-encodes the return value; iOS/macOS returns the raw string.
String? _parseSvgResult(Object result) {
  final raw = result.toString();
  try {
    final decoded = jsonDecode(raw);
    return decoded is String && decoded.isNotEmpty ? decoded : null;
  } on FormatException {
    return raw.isNotEmpty && raw != 'null' ? raw : null;
  }
}

/// Encodes a Dart string as a JSON string literal for safe JS interpolation.
String _jsonEncodeString(String s) {
  final buf = StringBuffer('"');
  for (final rune in s.runes) {
    switch (rune) {
      case 0x22:
        buf.write(r'\"');
      case 0x5c:
        buf.write(r'\\');
      case 0x08:
        buf.write(r'\b');
      case 0x09:
        buf.write(r'\t');
      case 0x0a:
        buf.write(r'\n');
      case 0x0c:
        buf.write(r'\f');
      case 0x0d:
        buf.write(r'\r');
      default:
        if (rune < 0x20 || rune == 0x2028 || rune == 0x2029) {
          buf.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        } else {
          buf.writeCharCode(rune);
        }
    }
  }
  buf.write('"');
  return buf.toString();
}
