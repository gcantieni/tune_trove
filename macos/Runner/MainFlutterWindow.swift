import Cocoa
import FlutterMacOS
import MusicKit
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
    private var musicKitBridge: AnyObject?
    private var cloudKitSyncBridge: AnyObject?
    private var audioImportBridge: AnyObject?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        // Audio file import (drag-and-drop + "Open With") works on all supported
        // macOS versions, so register it outside the macOS 14 gate.
        let importBridge = AudioImportBridge()
        importBridge.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
        audioImportBridge = importBridge

        // Overlay a transparent drop target above the Flutter view so audio files
        // dragged onto the window are imported. Registering drag types on the
        // NSWindow itself does not work once a Flutter view fills it; the overlay
        // passes mouse events through (hitTest -> nil) so the UI stays usable.
        if let contentView = self.contentView {
            let dropView = AudioFileDropView(frame: contentView.bounds)
            dropView.autoresizingMask = [.width, .height]
            contentView.addSubview(dropView)
        }

        if #available(macOS 14, *) {
            let bridge = MusicKitBridge()
            bridge.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
            musicKitBridge = bridge

            let syncBridge = CloudKitSyncBridge()
            syncBridge.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
            cloudKitSyncBridge = syncBridge

            // Needed to receive CloudKit's silent change pushes.
            NSApplication.shared.registerForRemoteNotifications()
        }

        super.awakeFromNib()
    }
}

/// Transparent overlay that accepts audio files dropped onto the window and
/// forwards them to the import bridge. Returns nil from `hitTest` so ordinary
/// mouse events reach the Flutter view underneath.
final class AudioFileDropView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return audioURLs(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = audioURLs(from: sender)
        guard !urls.isEmpty else { return false }
        for url in urls { AudioImportBridge.receive(url) }
        return true
    }

    /// File URLs on the drag pasteboard whose type is some kind of audio.
    private func audioURLs(from sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return objects.filter { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else {
                return false
            }
            return type.conforms(to: .audio)
        }
    }
}
