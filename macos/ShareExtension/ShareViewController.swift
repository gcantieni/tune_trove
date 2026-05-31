import Cocoa
import UniformTypeIdentifiers
import os

/// macOS Share Extension: copies shared audio into the App Group container's
/// `Imports/` folder; the main app drains it on launch/foreground
/// (`AudioImportBridge.drainSharedImports()`). Auto-completes with no UI.
///
/// Voice Memos vends the recording as a lazy, security-scoped in-place file that
/// the `load*Representation` APIs can't open ("no such file"). The working recipe
/// (see SHARE_EXTENSION.md): `loadObject(ofClass: URL.self)` returns a URL to an
/// already-materialized temp copy → start its security scope → `NSFileCoordinator`
/// read (`.forUploading`) → write the bytes into the App Group.
class ShareViewController: NSViewController {
    private let appGroupId = "group.com.gcantieni.tuneTrove"
    private let importsSubdir = "Imports"
    private let log = Logger(
        subsystem: "com.gcantieni.tuneTrove.ShareExtension", category: "share")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        handleShare()
    }

    private func handleShare() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }

        guard !providers.isEmpty else {
            complete()
            return
        }

        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            importAudio(provider) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.complete() }
    }

    private func importAudio(_ provider: NSItemProvider, done: @escaping () -> Void) {
        let audioType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .audio) == true
        } ?? UTType.audio.identifier
        let name = filename(for: provider, audioType: audioType)

        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { done(); return }
            guard let url else {
                self.log.error("loadObject(URL) nil err=\(error?.localizedDescription ?? "nil", privacy: .public)")
                done()
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: .forUploading, error: &coordError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    self.write(data: data, name: name)
                } catch {
                    self.log.error("read failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            if let coordError {
                self.log.error("coord error: \(coordError.localizedDescription, privacy: .public)")
            }
            done()
        }
    }

    /// suggestedName from Voice Memos has no extension; append the type's.
    private func filename(for provider: NSItemProvider, audioType: String) -> String {
        var name = provider.suggestedName ?? "shared_audio"
        if (name as NSString).pathExtension.isEmpty {
            let ext = UTType(audioType)?.preferredFilenameExtension ?? "m4a"
            name += ".\(ext)"
        }
        return name
    }

    private func importsDir() -> URL? {
        let fm = FileManager.default
        guard let container = fm.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId) else {
            log.error("containerURL nil — App Group not provisioned")
            return nil
        }
        let dir = container.appendingPathComponent(importsSubdir, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(data: Data, name: String) {
        guard let dir = importsDir() else { return }
        let dest = unique(in: dir, name: name)
        do {
            try data.write(to: dest)
        } catch {
            log.error("write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func unique(in dir: URL, name: String) -> URL {
        let fm = FileManager.default
        let ns = (name.isEmpty ? "shared_audio.m4a" : name) as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        var candidate = dir.appendingPathComponent(ns as String)
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
