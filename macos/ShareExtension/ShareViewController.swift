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
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        let audioProviders = attachments.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
        }
        // Apple Music shares a web URL (public.url), not audio. Only consider URL
        // items when there's no audio (a Voice Memo also vends a public.url alias).
        let urlProviders = audioProviders.isEmpty
            ? attachments.filter {
                $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            }
            : []

        guard !audioProviders.isEmpty || !urlProviders.isEmpty else {
            complete()
            return
        }

        let group = DispatchGroup()
        for provider in audioProviders {
            group.enter()
            importAudio(provider) { group.leave() }
        }
        for provider in urlProviders {
            group.enter()
            importURL(provider) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.complete() }
    }

    /// Apple Music (and similar) share a web link as a `public.url` item. We only
    /// ingest Apple Music links: the URL is written as a tiny sidecar file in the
    /// App Group inbox, which the app resolves to a `music-catalog:` recording
    /// (see `AudioImportBridge.drainSharedImports`).
    private func importURL(_ provider: NSItemProvider, done: @escaping () -> Void) {
        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { done(); return }
            guard let url, url.host?.hasSuffix("music.apple.com") == true else {
                if let error {
                    self.log.error("loadObject(URL) err=\(error.localizedDescription, privacy: .public)")
                }
                done()
                return
            }
            self.writeUrlSidecar(url)
            done()
        }
    }

    /// Writes the shared link into the App Group `Imports/` dir as a
    /// `<name>.tunetroveurl` text file; the app recognizes the extension and
    /// delivers the contents to Dart as a URL rather than a file.
    private func writeUrlSidecar(_ url: URL) {
        guard let dir = importsDir() else { return }
        let title = url.deletingPathExtension().lastPathComponent
        let base = title.isEmpty ? "shared_link" : title
        let dest = unique(in: dir, name: "\(base).tunetroveurl")
        do {
            try url.absoluteString.write(to: dest, atomically: true, encoding: .utf8)
        } catch {
            log.error("url sidecar write failed: \(error.localizedDescription, privacy: .public)")
        }
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
        // Foreground the host app so it drains the App Group inbox immediately,
        // rather than waiting for the user to switch to it manually. macOS lets
        // an extension open a URL via NSWorkspace; the scheme is registered in
        // macos/Runner/Info.plist and handled in AppDelegate.application(_:open:).
        NSWorkspace.shared.open(URL(string: "tunetrove://import")!)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
