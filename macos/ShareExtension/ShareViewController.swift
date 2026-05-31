import Cocoa
import UniformTypeIdentifiers
import os

/// macOS Share Extension: copies shared audio into the App Group container's
/// `Imports/` folder; the main app drains it on launch/foreground
/// (`AudioImportBridge.drainSharedImports()`). Auto-completes with no UI.
///
/// Voice Memos shares its recording in a way a sandboxed extension can't open by
/// URL (loadItem / loadFileRepresentation / loadInPlaceFileRepresentation all
/// fail "no such file"), so we ask the *source app* to serialize the bytes via
/// `loadDataRepresentation` (file path kept only as a fallback).
///
/// Logs at `.notice` (visible in Console.app without "Include Info Messages");
/// filter on "tuneTrove".
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
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let audioUTI = UTType.audio.identifier
        let audioProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(audioUTI)
        }
        log.notice("items=\(items.count) providers=\(providers.count) audio=\(audioProviders.count)")

        guard !audioProviders.isEmpty else {
            log.error("no audio attachments; completing")
            complete()
            return
        }

        for p in audioProviders {
            log.notice("name=\(p.suggestedName ?? "nil", privacy: .public) data=[\(p.registeredTypeIdentifiers.joined(separator: ","), privacy: .public)] inPlace=[\(p.registeredTypeIdentifiers(fileOptions: .openInPlace).joined(separator: ","), privacy: .public)] canURL=\(p.canLoadObject(ofClass: URL.self))")
        }

        let group = DispatchGroup()
        for provider in audioProviders {
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
        log.notice("using type \(audioType, privacy: .public) name=\(name, privacy: .public)")

        // Ask for the canonical URL Voice Memos vends (canURL=true) rather than
        // the title-named staging path, then read it via a security scope +
        // NSFileCoordinator `.forUploading` (which materializes provider files).
        // Logs the REAL path so we can see whether it's the UUID-backed file.
        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { done(); return }
            guard let url else {
                self.log.error("loadObject(URL) nil err=\(error?.localizedDescription ?? "nil", privacy: .public)")
                done()
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            self.log.notice("urlObject scoped=\(scoped) exists=\(FileManager.default.fileExists(atPath: url.path)) path=\(url.path, privacy: .public)")

            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: .forUploading, error: &coordError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    self.log.notice("read \(data.count) bytes")
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
            log.notice("wrote -> \(dest.path, privacy: .public)")
        } catch {
            log.error("write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func copyCoordinated(from url: URL, securityScoped: Bool, name: String) {
        guard let dir = importsDir() else { return }
        let scoped = securityScoped && url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            let dest = unique(in: dir, name: name)
            do {
                try FileManager.default.copyItem(at: readURL, to: dest)
                log.notice("copied -> \(dest.path, privacy: .public)")
            } catch {
                log.error("copy failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if let coordError {
            log.error("coordinate error: \(coordError.localizedDescription, privacy: .public)")
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
