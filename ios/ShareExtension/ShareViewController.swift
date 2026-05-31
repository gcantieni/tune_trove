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
        let name = filename(for: provider, audioType: audioType)

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
