import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tune_trove/feat/abc_midi/abc_midi_state.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// WebView-backed MIDI player that hosts `assets/abcjs/synth.html` and uses
/// abcjs's `synth` module to play ABC notation via the Web Audio API.
///
/// The play/stop control lives **inside** the WebView (a styled HTML button)
/// because WebKit only treats taps inside the WebView as user gestures, and
/// AudioContext can't `resume()` without one. Mount [viewWidget] wherever
/// the button should appear; Dart pushes the current tune's ABC via
/// [setCurrentAbc] so the button knows what to play.
class AbcMidiPlayer {
  late final WebViewController _controller;
  final _stateController = StreamController<AbcMidiState>.broadcast();
  Completer<void>? _ready;
  AbcMidiState _state = const AbcMidiState();

  AbcMidiPlayer() {
    _ready = Completer<void>();
    // WebKit (iOS / macOS) requires a user gesture before AudioContext can
    // leave the 'suspended' state. Our play() comes from Flutter via
    // runJavaScript, which WebKit doesn't count as a gesture, so we drop the
    // requirement here. Default on other platforms stays untouched.
    final isWebKit = WebViewPlatform.instance is WebKitWebViewPlatform;
    debugPrint(
      '[abc_midi] AbcMidiPlayer ctor: '
      'WebViewPlatform.instance=${WebViewPlatform.instance.runtimeType}, '
      'isWebKit=$isWebKit',
    );
    final params = isWebKit
        ? WebKitWebViewControllerCreationParams(
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            allowsInlineMediaPlayback: true,
          )
        : const PlatformWebViewControllerCreationParams();
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'AbcMidi',
        onMessageReceived: (msg) => _handleJsMessage(msg.message),
      )
      ..addJavaScriptChannel(
        'AbcMidiAsset',
        onMessageReceived: (msg) => _handleAssetRequest(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (_ready != null && !_ready!.isCompleted) _ready!.complete();
          },
          onWebResourceError: (err) {
            if (_ready != null && !_ready!.isCompleted) {
              _ready!.completeError(err);
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/abcjs/synth.html');
  }

  Stream<AbcMidiState> get stateStream => _stateController.stream;

  AbcMidiState get state => _state;

  /// Mount this where the Play button should appear. The WebView paints the
  /// styled HTML button and is the only surface that can capture the WebKit
  /// gesture required to unlock AudioContext.
  Widget viewWidget() => WebViewWidget(controller: _controller);

  /// Push Material theme colors into the WebView as CSS variables so the
  /// in-WebView button matches the surrounding Flutter UI.
  Future<void> setTheme(Map<String, String> cssVars) async {
    try {
      await _ready?.future;
      final entries = cssVars.entries
          .map((e) => '"${e.key}":"${e.value}"')
          .join(',');
      await _controller.runJavaScript('window.setTheme({$entries});');
    } catch (_) {
      // best-effort
    }
  }

  /// Push the active tune's ABC into the WebView so the in-WebView button
  /// can play it. Pass `null` to disable the button.
  Future<void> setCurrentAbc(String? abc) async {
    try {
      if (_ready == null) {
        _ready = Completer<void>();
        unawaited(_controller.loadFlutterAsset('assets/abcjs/synth.html'));
      }
      await _ready!.future;
      final encoded = abc == null ? 'null' : _jsonEncodeString(abc);
      await _controller.runJavaScript('window.setCurrentAbc($encoded);');
    } catch (_) {
      // best-effort; surfaced state still flows via the stream if it matters
    }
  }

  /// Programmatic stop. Real play/stop is triggered by the in-WebView button
  /// click (so the gesture lands in WebKit), but stop can be invoked from
  /// Dart since it doesn't need a gesture.
  Future<void> stop() async {
    try {
      await _controller.runJavaScript('window.stopAbc();');
    } catch (_) {
      // best-effort
    }
    _emit(const AbcMidiState());
  }

  void dispose() {
    _stateController.close();
  }

  Future<void> _handleAssetRequest(String raw) async {
    int? id;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      id = decoded['id'] as int?;
      final url = decoded['url'] as String?;
      if (id == null || url == null) return;
      final assetKey = _assetKeyForNoteUrl(url);
      final bytes = await rootBundle.load(assetKey);
      final b64 = base64Encode(bytes.buffer.asUint8List());
      await _controller.runJavaScript('window.deliverAsset($id, "$b64");');
    } catch (_) {
      if (id != null) {
        try {
          await _controller.runJavaScript('window.deliverAsset($id, null);');
        } catch (_) {
          // best-effort
        }
      }
    }
  }

  /// Maps a relative URL from inside the WebView (e.g.
  /// `./soundfonts/acoustic_grand_piano-mp3/A4.mp3`) to the Flutter asset key
  /// (`assets/abcjs/soundfonts/acoustic_grand_piano-mp3/A4.mp3`).
  String _assetKeyForNoteUrl(String url) {
    final cleaned = url.startsWith('./') ? url.substring(2) : url;
    return 'assets/abcjs/$cleaned';
  }

  void _handleJsMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final kind = decoded['kind'];
      final detail = decoded['detail'];
      switch (kind) {
        case 'loading':
          _emit(const AbcMidiState(status: AbcMidiStatus.loading));
        case 'playing':
          _emit(const AbcMidiState(status: AbcMidiStatus.playing));
        case 'ended':
        case 'stopped':
          _emit(const AbcMidiState());
        case 'error':
          _emit(
            AbcMidiState(
              status: AbcMidiStatus.error,
              message: detail is String ? detail : null,
            ),
          );
        case 'debug':
          debugPrint('[abc_midi] $detail');
      }
    } on FormatException {
      // ignore malformed messages
    }
  }

  void _emit(AbcMidiState next) {
    _state = next;
    _stateController.add(next);
  }
}

final abcMidiPlayerProvider = Provider<AbcMidiPlayer>((ref) {
  final player = AbcMidiPlayer();
  ref.onDispose(player.dispose);
  return player;
});

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
