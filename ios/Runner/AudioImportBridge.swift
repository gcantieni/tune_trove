import Foundation
#if canImport(UIKit)
import Flutter
import UIKit
#elseif canImport(AppKit)
import FlutterMacOS
#endif

enum AudioImportChannels {
    static let method = "com.gcantieni.tuneTrove/audio_import"
    static let event  = "com.gcantieni.tuneTrove/audio_import_events"
}

/// Receives audio files shared or opened into the app: the iOS share sheet
/// ("Copy to Tune Trove", e.g. from Voice Memos or Files) and macOS Finder
/// "Open With" / drag-and-drop onto the window.
///
/// The scene delegate forwards each incoming file URL here. Because the scene
/// can connect before the implicit Flutter engine (and therefore this bridge)
/// exists, URLs delivered early are buffered in `pendingURLs` and drained when
/// the bridge is set up.
///
/// Delivery to Dart uses two paths so cold and warm launches each fire exactly
/// once:
///   - Cold launch: the copied file is stashed in `pendingFile` and pulled by
///     the `getInitialSharedFile` method call when the recording list mounts.
///   - Warm launch: if Dart is already listening, the file is pushed on the
///     event channel instead.
@MainActor
final class AudioImportBridge: NSObject {
    /// The active bridge, so the scene delegate can deliver URLs without
    /// threading a reference through Flutter's engine plumbing.
    static weak var shared: AudioImportBridge?

    /// URLs received before the bridge was set up (scene connected first).
    private static var pendingURLs: [URL] = []

    /// Entry point for the scene delegate. Routes the URL to the live bridge or
    /// buffers it until one exists.
    static func receive(_ url: URL) {
        if let bridge = shared {
            bridge.handleIncomingURL(url)
        } else {
            pendingURLs.append(url)
        }
    }

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    /// A file received before Dart asked for it (cold launch). Consumed by
    /// `getInitialSharedFile`.
    private var pendingFile: [String: Any]?

    func setup(binaryMessenger: FlutterBinaryMessenger) {
        let method = FlutterMethodChannel(
            name: AudioImportChannels.method,
            binaryMessenger: binaryMessenger
        )
        let event = FlutterEventChannel(
            name: AudioImportChannels.event,
            binaryMessenger: binaryMessenger
        )
        method.setMethodCallHandler { [weak self] call, result in
            MainActor.assumeIsolated { self?.handleMethod(call, result: result) }
        }
        event.setStreamHandler(self)
        methodChannel = method
        eventChannel = event
        AudioImportBridge.shared = self

        // Drain anything the scene delivered before we existed.
        let buffered = AudioImportBridge.pendingURLs
        AudioImportBridge.pendingURLs = []
        for url in buffered { handleIncomingURL(url) }
    }

    private func handleMethod(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getInitialSharedFile":
            let file = pendingFile
            pendingFile = nil
            result(file)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Copies the shared file into a temp location we own and delivers it to
    /// Dart (pushed if listening, otherwise buffered for the cold-launch pull).
    func handleIncomingURL(_ url: URL) {
        guard url.isFileURL, let payload = copyToTemp(url) else { return }
        if let sink = eventSink {
            sink(payload)
        } else {
            pendingFile = payload
        }
    }

    private func copyToTemp(_ url: URL) -> [String: Any]? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let name = url.lastPathComponent.isEmpty ? "shared_audio.m4a" : url.lastPathComponent
        let tempDir = fm.temporaryDirectory.appendingPathComponent(
            "audio_import", isDirectory: true)
        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let dest = tempDir.appendingPathComponent(name)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: url, to: dest)
            return ["path": dest.path, "name": dest.lastPathComponent]
        } catch {
            print("[AudioImport] copy failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - FlutterStreamHandler

extension AudioImportBridge: FlutterStreamHandler {
    // Flutter invokes these on the platform (main) thread.
    nonisolated func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        MainActor.assumeIsolated { self.eventSink = events }
        return nil
    }

    nonisolated func onCancel(withArguments arguments: Any?) -> FlutterError? {
        MainActor.assumeIsolated { self.eventSink = nil }
        return nil
    }
}
