import UIKit
import UniformTypeIdentifiers
import os

/// iOS Share Extension. Two flows depending on what's shared:
///
/// - **Audio** (e.g. a Voice Memo): presents a small inline form (Name +
///   Performers), copies the audio into the App Group `Imports/` folder, and on
///   Save writes a `<file>.tunetrovemeta` JSON sidecar next to it. The main app
///   drains the inbox (`AudioImportBridge.drainSharedImports()`) and, seeing the
///   sidecar, inserts the recording silently — so the user stays in the source
///   app, no launch required.
/// - **URL** (e.g. an Apple Music link): no form; writes a `.tunetroveurl`
///   sidecar and foregrounds the host app, which resolves it via MusicKit.
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

    private let nameField = UITextField()
    private let performersField = UITextField()
    private var saveItem: UIBarButtonItem?
    /// The audio file copied into the App Group, set once the background copy
    /// finishes; the Save sidecar is keyed to it.
    private var copiedAudioURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        // A Voice Memo also vends a `public.url` alias, so audio wins when both
        // are present; only treat a share as a URL when there's no audio.
        if let audio = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
        }) {
            setupForm()
            startCopy(audio)
            return
        }
        let urlProviders = attachments.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }
        guard !urlProviders.isEmpty else { cancel(); return }
        view.backgroundColor = .clear
        handleURLShare(urlProviders)
    }

    // MARK: - Audio form flow

    private func setupForm() {
        view.backgroundColor = .systemBackground

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: "Add Recording")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
        let save = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(onSave))
        save.isEnabled = false  // until the background copy finishes
        navItem.rightBarButtonItem = save
        saveItem = save
        navBar.setItems([navItem], animated: false)
        view.addSubview(navBar)

        configure(nameField, placeholder: "Name")
        configure(performersField, placeholder: "Performers")
        nameField.returnKeyType = .next
        performersField.returnKeyType = .done

        let stack = UIStackView(arrangedSubviews: [nameField, performersField])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -16),
        ])
        nameField.becomeFirstResponder()
    }

    private func configure(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .words
        field.clearButtonMode = .whileEditing
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    /// Copies the shared audio into the App Group on a background queue while the
    /// user fills in the form; enables Save (and prefills the name) when done.
    private func startCopy(_ provider: NSItemProvider) {
        let audioType = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .audio) == true
        } ?? UTType.audio.identifier

        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { return }
            guard let url else {
                self.log.error("loadObject(URL) nil err=\(error?.localizedDescription ?? "nil", privacy: .public)")
                DispatchQueue.main.async { self.copyFailed() }
                return
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            // Derive the name only now that we have the materialized URL: iOS Voice
            // Memos leaves `suggestedName` nil but the URL's last path component
            // carries the recording's real title, so it's the better fallback.
            let name = self.filename(
                suggested: provider.suggestedName, url: url, audioType: audioType)

            var dest: URL?
            var coordError: NSError?
            NSFileCoordinator().coordinate(
                readingItemAt: url, options: .forUploading, error: &coordError
            ) { readURL in
                dest = self.copyToGroup(from: readURL, name: name)
            }
            if let coordError {
                self.log.error("coord error: \(coordError.localizedDescription, privacy: .public)")
            }
            DispatchQueue.main.async {
                if let dest { self.copyFinished(dest) } else { self.copyFailed() }
            }
        }
    }

    private func copyFinished(_ dest: URL) {
        copiedAudioURL = dest
        if nameField.text?.isEmpty ?? true {
            nameField.text = dest.deletingPathExtension().lastPathComponent
        }
        saveItem?.isEnabled = true
    }

    private func copyFailed() {
        let alert = UIAlertController(
            title: "Import failed",
            message: "Couldn't read the shared audio.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in self?.cancel()
        })
        present(alert, animated: true)
    }

    @objc private func onSave() {
        guard let audioURL = copiedAudioURL else { return }
        let typedName = (nameField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let performers = (performersField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = typedName.isEmpty
            ? audioURL.deletingPathExtension().lastPathComponent : typedName
        writeMetaSidecar(forAudio: audioURL, name: name, performers: performers)
        // Silent save: deliberately do NOT foreground the host app.
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func onCancel() {
        if let audioURL = copiedAudioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        cancel()
    }

    /// Writes the `<audio>.tunetrovemeta` JSON sidecar the app reads to perform a
    /// silent insert. `performers` is omitted when empty.
    private func writeMetaSidecar(
        forAudio audioURL: URL, name: String, performers: String
    ) {
        let metaURL = audioURL.appendingPathExtension("tunetrovemeta")
        var dict: [String: Any] = ["name": name]
        if !performers.isEmpty { dict["performers"] = performers }
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            try data.write(to: metaURL, options: .atomic)
        } catch {
            log.error("meta sidecar write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - URL flow (Apple Music links)

    private func handleURLShare(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            importURL(provider) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.completeAndOpenApp() }
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

    // MARK: - Shared helpers

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
    /// Returns the destination URL (the form keys its sidecar to it), nil on error.
    private func copyToGroup(from readURL: URL, name: String) -> URL? {
        guard let dir = importsDir() else { return nil }
        let dest = unique(in: dir, name: name)
        do {
            try FileManager.default.copyItem(at: readURL, to: dest)
            return dest
        } catch {
            log.error("copy failed: \(error.localizedDescription, privacy: .public)")
            return nil
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

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: "com.gcantieni.tuneTrove.ShareExtension", code: 0))
    }

    private func completeAndOpenApp() {
        // Foreground the host app so it drains the App Group inbox immediately.
        // Fire the open first, then finish the request on the next runloop turn:
        // calling `completeRequest` synchronously tears the extension down before
        // the system has dispatched the launch, so the app never comes forward.
        openHostApp()
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(
                returningItems: nil, completionHandler: nil)
        }
    }

    /// ⚠️ UNOFFICIAL / GRAY-AREA — keep isolated and easy to rip out.
    ///
    /// There is NO public API for an iOS share extension to launch its host app:
    /// `UIApplication.open(_:options:completionHandler:)` is annotated
    /// `unavailable` in app extensions. The widely-used workaround walks the
    /// responder chain to whatever object responds to the legacy `openURL:`
    /// selector (the shared `UIApplication`) and invokes it dynamically, which
    /// sidesteps the compile-time availability check. Only the URL flow needs it;
    /// the audio flow saves silently and never foregrounds the app.
    ///
    /// This works as of iOS 17/18 but is undocumented and Apple could break it in
    /// any release. The scheme is registered in ios/Runner/Info.plist and handled
    /// in SceneDelegate.
    private func openHostApp() {
        guard let url = URL(string: "tunetrove://import") else { return }
        let selector = NSSelectorFromString("openURL:")
        // Walk the responder chain for the actual `UIApplication` and invoke
        // `openURL:` on *it*. Targeting "the first responder that responds to the
        // selector" doesn't work — `UIViewController` and other responders answer
        // `openURL:` too, and performing it on them silently no-ops, so the app
        // never foregrounds.
        var responder: UIResponder? = self
        while let current = responder {
            if let app = current as? UIApplication, app.responds(to: selector) {
                app.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }
}
