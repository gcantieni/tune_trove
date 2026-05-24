# Roadmap: ABC Notation Rendering on Linux

## Problem

`webview_flutter` (the target replacement for `flutter_inappwebview`) does not support Linux. The current ABC→SVG rendering pipeline depends on a WebView to host the `abcjs` JavaScript library. On Linux, if we migrate to `webview_flutter`, we lose ABC rendering entirely and fall back to plaintext ABC display.

## Goal

Implement `AbcRenderer` for Linux using a process-based JavaScript execution approach — no WebView required.

## Proposed Approach: Process-based JS via `dart:io`

Spawn a headless JS runtime as a subprocess, pipe the ABC string in, and read the SVG string back via stdout. The `render.html` asset already proves abcjs works standalone, so the same logic can be extracted into a pure JS script.

### New asset: `assets/abcjs/render_cli.js`

A Node-compatible script that:
1. Reads the ABC string from `stdin` (or a CLI argument)
2. Loads abcjs (requires a CommonJS-compatible build of abcjs, or use the `--experimental-vm-modules` path with the existing ESM build)
3. Calls `ABCJS.renderAbc(...)` using `jsdom` as a DOM shim
4. Writes the SVG string to `stdout`, exits 0
5. Writes errors to `stderr`, exits 1

### New class: `ProcessAbcRenderer implements AbcRenderer`

Located at `lib/feat/abc_render/process_abc_renderer.dart`:

```dart
class ProcessAbcRenderer implements AbcRenderer {
  // Spawns: node assets/abcjs/render_cli.js
  // Passes ABC via stdin, reads SVG from stdout
  // Times out after 5s
}
```

### Platform-conditional provider

`abc_renderer.dart` already has `abcRendererProvider`. Make it platform-aware:

```dart
final abcRendererProvider = Provider<AbcRenderer>((ref) {
  if (Platform.isLinux) {
    final r = ProcessAbcRenderer();
    ref.onDispose(r.dispose);
    return r;
  }
  final r = WebViewAbcRenderer();
  ref.onDispose(r.dispose);
  return r;
});
```

## JS Runtime Options

| Runtime | Notes |
|---|---|
| `node` (system) | Most widely available on Linux dev machines and CI. Requires it installed; not bundled. Good enough for dev and desktop. |
| `quickjs` (bundled) | ~700 KB binary, no dependencies. Can be bundled as a Flutter asset and extracted to a temp dir at runtime. Ideal for distro-independent builds. |
| `deno` (system) | Supports ESM natively; no `jsdom` needed if abcjs ESM build is used. Less universally installed. |

**Recommended path:** Start with system `node` (fail gracefully if not found → plaintext fallback). Bundle `quickjs` later if distro-independent builds become a requirement.

## DOM Shim for abcjs

abcjs uses DOM APIs (`document.createElement`, `SVGElement`, etc.) internally. In a headless Node environment, a DOM shim is required:

- [`jsdom`](https://github.com/jsdom/jsdom) — full DOM implementation for Node. Install as a dev-time bundled dep and include in the CLI script.
- Alternatively, explore whether `abcjs` exposes a pure-JS path (it does: `ABCJS.renderAbc` can accept a plain object as the container with a `outerHTML` getter if monkey-patched).

The existing `render.html` shim is a good reference point for what DOM surface abcjs actually touches.

## Implementation Steps (when ready)

1. Write `assets/abcjs/render_cli.js` — extract the abcjs render logic from `render.html` into a standalone Node script with stdin/stdout I/O
2. Test it locally: `echo "X:1\nT:Test\nK:D\nABCD|" | node assets/abcjs/render_cli.js`
3. Implement `ProcessAbcRenderer` in `lib/feat/abc_render/process_abc_renderer.dart`
4. Add TDD unit tests (mock `Process` or use an integration test with real Node)
5. Update `abcRendererProvider` in `abc_renderer.dart` with `Platform.isLinux` branch
6. Verify: `flutter run -d linux` renders SVG notation on a Linux machine

## Open Questions

- Should `ProcessAbcRenderer` fail silently (return `null`) if `node` is not found, or surface a user-visible warning?
- Does abcjs need `jsdom`, or can we mock just the handful of DOM methods it calls?
- If bundling `quickjs`: what's the extraction + caching strategy for the binary asset?

## Relationship to webview_flutter Migration

This roadmap item is a **prerequisite for full Linux support** after migrating from `flutter_inappwebview` to `webview_flutter`. The migration plan at `.claude/plans/snappy-squishing-kettle.md` identifies Linux as the main gap; this document describes how to fill it.
