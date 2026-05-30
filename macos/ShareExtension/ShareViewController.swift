import Cocoa
import UniformTypeIdentifiers

/// macOS Share Extension: the only way to appear in the system Share menu (the
/// Voice Memos / Finder "Share" button). Copies shared audio into the App Group
/// container's `Imports/` folder; the main app drains it on launch/foreground
/// (`AudioImportBridge.drainSharedImports()`). Auto-completes with no UI.
class ShareViewController: NSViewController {
    // Must match `AudioImportAppGroup` in the main app + the App Groups
    // capability on every target.
    private let appGroupId = "group.com.gcantieni.tuneTrove"
    private let importsSubdir = "Imports"

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        let audioUTI = UTType.audio.identifier
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(audioUTI) }

        guard !providers.isEmpty else { return complete() }

        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: audioUTI) { [weak self] url, _ in
                if let url = url { self?.copyToGroup(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in self?.complete() }
    }

    private func copyToGroup(_ url: URL) {
        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId) else { return }
        let importsDir = container.appendingPathComponent(
            importsSubdir, isDirectory: true)
        try? fm.createDirectory(at: importsDir, withIntermediateDirectories: true)
        let dest = uniqueDestination(in: importsDir, name: url.lastPathComponent)
        try? fm.copyItem(at: url, to: dest)
    }

    private func uniqueDestination(in dir: URL, name: String) -> URL {
        let fm = FileManager.default
        let ns = name as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        var candidate = dir.appendingPathComponent(name.isEmpty ? "shared_audio.m4a" : name)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            let next = ext.isEmpty ? "\(base)_\(n)" : "\(base)_\(n).\(ext)"
            candidate = dir.appendingPathComponent(next)
            n += 1
        }
        return candidate
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
