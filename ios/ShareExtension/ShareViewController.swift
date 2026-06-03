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
/// - **URL** (e.g. an Apple Music link): the same form (Name prefilled from the
///   link's slug + Performers), and on Save a `.tunetroveurl` JSON sidecar
///   (`{ url, name, performers, autosave }`). The app resolves the link to a
///   `music-catalog:` recording and inserts it silently — like the audio flow.
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
    /// finishes; the Save sidecar is keyed to it. Mutually exclusive with
    /// `sharedURL` — exactly one is set depending on the share type.
    private var copiedAudioURL: URL?
    /// The shared Apple Music link, set once the URL item loads.
    private var sharedURL: URL?
    /// Name to fall back to if the user clears the Name field before saving.
    private var fallbackName = "Shared Link"

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
        if let urlProvider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            setupForm()
            startURL(urlProvider)
            return
        }
        cancel()
    }

    // MARK: - Form

    private func setupForm() {
        view.backgroundColor = .systemBackground

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        let navItem = UINavigationItem(title: "Add Recording")
        navItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(onCancel))
        let save = UIBarButtonItem(
            barButtonSystemItem: .save, target: self, action: #selector(onSave))
        save.isEnabled = false  // until the audio copy / URL load finishes
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
        let typedName = (nameField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let performers = (performersField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let audioURL = copiedAudioURL {
            let name = typedName.isEmpty
                ? audioURL.deletingPathExtension().lastPathComponent : typedName
            writeMetaSidecar(forAudio: audioURL, name: name, performers: performers)
        } else if let sharedURL {
            let name = typedName.isEmpty ? fallbackName : typedName
            writeUrlSidecar(sharedURL, name: name, performers: performers)
        } else {
            return
        }
        // Silent save: deliberately do NOT foreground the host app.
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func onCancel() {
        // Only the audio flow left a file behind; the URL flow has nothing to undo.
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

    /// Loads the shared `public.url`. We only handle Apple Music links; anything
    /// else gets a brief alert and dismisses. On success, prefills the Name field
    /// from the link's slug and enables Save.
    private func startURL(_ provider: NSItemProvider) {
        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, error in
            guard let self else { return }
            guard let url, url.host?.hasSuffix("music.apple.com") == true else {
                if let error {
                    self.log.error("loadObject(URL) err=\(error.localizedDescription, privacy: .public)")
                }
                DispatchQueue.main.async { self.unsupportedURL() }
                return
            }
            DispatchQueue.main.async { self.urlLoaded(url) }
        }
    }

    private func urlLoaded(_ url: URL) {
        sharedURL = url
        if let slugName = appleMusicName(from: url) { fallbackName = slugName }
        if nameField.text?.isEmpty ?? true { nameField.text = fallbackName }
        saveItem?.isEnabled = true
    }

    private func unsupportedURL() {
        let alert = UIAlertController(
            title: "Unsupported link",
            message: "Only Apple Music links can be added this way.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) {
            [weak self] _ in self?.cancel()
        })
        present(alert, animated: true)
    }

    /// Writes the shared link to the App Group `Imports/` dir as a
    /// `.tunetroveurl` JSON sidecar (`{ url, name, performers, autosave }`); the
    /// app resolves it to a `music-catalog:` recording and inserts it silently.
    /// The filename is incidental (the app reads the contents), so it's fixed.
    private func writeUrlSidecar(_ url: URL, name: String, performers: String) {
        guard let dir = importsDir() else { return }
        let dest = unique(in: dir, name: "shared_link.tunetroveurl")
        var dict: [String: Any] = [
            "url": url.absoluteString, "name": name, "autosave": true,
        ]
        if !performers.isEmpty { dict["performers"] = performers }
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            try data.write(to: dest, options: .atomic)
        } catch {
            log.error("url sidecar write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Best-effort title from an Apple Music link's slug, mirroring the Dart
    /// `appleMusicNameFromSlug`: `…/song/the-morning-dew/1` → "The Morning Dew".
    private func appleMusicName(from url: URL) -> String? {
        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let lower = segments.map { $0.lowercased() }
        for keyword in ["song", "album"] {
            guard let i = lower.firstIndex(of: keyword), i + 1 < segments.count
            else { continue }
            let words = segments[i + 1].split(separator: "-").map {
                $0.prefix(1).uppercased() + $0.dropFirst()
            }
            let name = words.joined(separator: " ")
            if !name.isEmpty { return name }
        }
        return nil
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
}
