import UIKit
import UniformTypeIdentifiers
import os

/// iOS Share Extension: copies shared audio into the App Group container's
/// `Imports/` folder; the main app drains it on launch/foreground
/// (`AudioImportBridge.drainSharedImports()`). Auto-completes with no UI.
///
/// Voice Memos vends the recording as a lazy, security-scoped in-place file that
/// the `load*Representation` APIs can't open ("no such file"). The working recipe
/// (see ../../macos/ShareExtension/SHARE_EXTENSION.md): `loadObject(ofClass:
/// URL.self)` returns a URL to an already-materialized temp copy → start its
/// security scope → `NSFileCoordinator` read (`.forUploading`) → write the bytes
/// into the App Group. iOS uses `copyItem` instead of `Data(contentsOf:)` to stay
/// inside the extension's tight (~120 MB) memory budget on long recordings.
class ShareViewController: UIViewController {
    // Must match `AudioImportAppGroup` in the main app + the App Groups
    // capability on every target.
    private let appGroupId = "group.com.gcantieni.tuneTrove"
    private let importsSubdir = "Imports"
    private let log = Logger(
        subsystem: "com.gcantieni.tuneTrove.ShareExtension", category: "share")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
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
            log.notice("wrote url -> \(dest.lastPathComponent, privacy: .public)")
        } catch {
            log.error("url sidecar write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func importAudio(_ provider: NSItemProvider, done: @escaping () -> Void) {
        // Verbose diagnostics for the first device test — iOS Voice Memos may vend
        // differently than macOS, so confirm `canURL`/`data` from Console before
        // trusting the loader. Strip to `.error` in a follow-up once it imports.
        log.notice("""
            name=\(provider.suggestedName ?? "nil", privacy: .public) \
            data=[\(provider.registeredTypeIdentifiers.joined(separator: ","), privacy: .public)] \
            inPlace=[\(provider.registeredTypeIdentifiers(fileOptions: .openInPlace).joined(separator: ","), privacy: .public)] \
            canURL=\(provider.canLoadObject(ofClass: URL.self), privacy: .public)
            """)

        let audioType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .audio) == true
        } ?? UTType.audio.identifier

        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { done(); return }
            guard let url else {
                self.log.error("loadObject(URL) nil err=\(error?.localizedDescription ?? "nil", privacy: .public)")
                done()
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            self.log.notice("urlObject \(url.path, privacy: .public) scoped=\(scoped, privacy: .public)")
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            // Derive the name only now that we have the materialized URL: iOS Voice
            // Memos leaves `suggestedName` nil but the URL's last path component
            // carries the recording's real title, so it's the better fallback.
            let name = self.filename(
                suggested: provider.suggestedName, url: url, audioType: audioType)

            var coordError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: .forUploading, error: &coordError) { readURL in
                self.copyToGroup(from: readURL, name: name)
            }
            if let coordError {
                self.log.error("coord error: \(coordError.localizedDescription, privacy: .public)")
            }
            done()
        }
    }

    /// Builds the destination filename. Prefers `suggestedName`; on iOS Voice
    /// Memos that's nil, so it falls back to the materialized URL's filename
    /// (which carries the recording title) before the generic `shared_audio`.
    /// `suggestedName` has no extension, so append the type's when missing.
    private func filename(suggested: String?, url: URL, audioType: String) -> String {
        var name = suggested ?? ""
        if name.isEmpty {
            let fromURL = url.deletingPathExtension().lastPathComponent
            name = fromURL.isEmpty ? "shared_audio" : fromURL
        }
        if (name as NSString).pathExtension.isEmpty {
            let ext = url.pathExtension.isEmpty
                ? (UTType(audioType)?.preferredFilenameExtension ?? "m4a")
                : url.pathExtension
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

    /// Stream the file into the App Group with `copyItem` (not `Data(contentsOf:)`)
    /// to avoid loading a long recording fully into the extension's RAM budget.
    private func copyToGroup(from readURL: URL, name: String) {
        guard let dir = importsDir() else { return }
        let dest = unique(in: dir, name: name)
        do {
            try FileManager.default.copyItem(at: readURL, to: dest)
            log.notice("wrote -> \(dest.lastPathComponent, privacy: .public)")
        } catch {
            log.error("copy failed: \(error.localizedDescription, privacy: .public)")
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
        // Foreground the host app so it drains the App Group inbox immediately.
        // (Only useful once this extension actually writes a file — see the iOS
        // share read fix; harmless before then.)
        openHostApp()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    /// ⚠️ UNOFFICIAL / GRAY-AREA — keep isolated and easy to rip out.
    ///
    /// There is NO public API for an iOS share extension to launch its host app:
    /// `UIApplication.open(_:options:completionHandler:)` is annotated
    /// `unavailable` in app extensions. The widely-used workaround walks the
    /// responder chain to whatever object responds to the legacy `openURL:`
    /// selector (the shared `UIApplication`) and invokes it dynamically, which
    /// sidesteps the compile-time availability check.
    ///
    /// This works as of iOS 17/18 but is undocumented and Apple could break it in
    /// any release. The import itself does NOT depend on it — without it the user
    /// just foregrounds the app manually and the inbox drains on the next
    /// `didBecomeActive`. The scheme is registered in ios/Runner/Info.plist and
    /// handled in SceneDelegate.
    private func openHostApp() {
        guard let url = URL(string: "tunetrove://import") else { return }
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }
}
