import Cocoa
import UniformTypeIdentifiers
import os

/// macOS Share Extension. Two flows depending on what's shared:
///
/// - **Audio** (e.g. a Voice Memo): presents a small inline form (Name +
///   Performers), copies the audio into the App Group `Imports/` folder, and on
///   Save writes a `<file>.tunetrovemeta` JSON sidecar next to it.
/// - **URL** (e.g. an Apple Music link): the same form (Name prefilled from the
///   link's slug + Performers), and on Save a `.tunetroveurl` JSON sidecar
///   (`{ url, name, performers, autosave }`). The app resolves the link to a
///   `music-catalog:` recording.
///
/// On Save the host app is foregrounded (`tunetrove://import`) so it drains the
/// App Group inbox immediately (`AudioImportBridge.drainSharedImports()`).
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

    private let nameField = NSTextField()
    private let performersField = NSTextField()
    private var saveButton: NSButton?
    /// The audio file copied into the App Group, set once the background copy
    /// finishes; the Save sidecar is keyed to it. Mutually exclusive with
    /// `sharedURL` — exactly one is set depending on the share type.
    private var copiedAudioURL: URL?
    /// The shared Apple Music link, set once the URL item loads.
    private var sharedURL: URL?
    /// Name to fall back to if the user clears the Name field before saving.
    private var fallbackName = "Shared Link"

    // MARK: - Form

    override func loadView() {
        // Give the top-level view a concrete frame: a zero-size view can make the
        // host present an invisible/zero-height popover even with constraints set.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))

        let titleLabel = NSTextField(labelWithString: "Add Recording")
        titleLabel.font = .boldSystemFont(ofSize: 15)

        configure(nameField, placeholder: "Name")
        configure(performersField, placeholder: "Performers")

        let cancelButton = NSButton(
            title: "Cancel", target: self, action: #selector(onCancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"  // Esc
        let save = NSButton(title: "Save", target: self, action: #selector(onSave))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.isEnabled = false  // until the audio copy / URL load finishes
        saveButton = save

        let spacer = NSView()
        let buttonRow = NSStackView(views: [spacer, cancelButton, save])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let stack = NSStackView(views: [
            titleLabel, nameField, performersField, buttonRow,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(
                equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(
                equalTo: container.bottomAnchor, constant: -16),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            performersField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            container.widthAnchor.constraint(equalToConstant: 360),
        ])
        view = container
        preferredContentSize = NSSize(width: 360, height: 180)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(nameField)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        // Temporary launch diagnostic — confirms the new extension is actually
        // invoked and shows what each attachment vends. Strip once verified.
        log.notice("""
            share invoked: \
            \(attachments.map { $0.registeredTypeIdentifiers.joined(separator: "|") }.joined(separator: " ; "), privacy: .public)
            """)
        // A Voice Memo also vends a `public.url` alias, so audio wins when both
        // are present; only treat a share as a URL when there's no audio.
        if let audio = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier)
        }) {
            startCopy(audio)
            return
        }
        if let urlProvider = attachments.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            startURL(urlProvider)
            return
        }
        cancel()
    }

    private func configure(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
        field.isEditable = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Audio flow

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
                do {
                    let data = try Data(contentsOf: readURL)
                    dest = self.write(data: data, name: name)
                } catch {
                    self.log.error("read failed: \(error.localizedDescription, privacy: .public)")
                }
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
        if nameField.stringValue.isEmpty {
            nameField.stringValue = dest.deletingPathExtension().lastPathComponent
        }
        saveButton?.isEnabled = true
    }

    private func copyFailed() {
        presentAlert(title: "Import failed", message: "Couldn't read the shared audio.")
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
                DispatchQueue.main.async {
                    self.presentAlert(
                        title: "Unsupported link",
                        message: "Only Apple Music links can be added this way.")
                }
                return
            }
            DispatchQueue.main.async { self.urlLoaded(url) }
        }
    }

    private func urlLoaded(_ url: URL) {
        sharedURL = url
        if let slugName = appleMusicName(from: url) { fallbackName = slugName }
        if nameField.stringValue.isEmpty { nameField.stringValue = fallbackName }
        saveButton?.isEnabled = true
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

    // MARK: - Save / Cancel

    @objc private func onSave() {
        let typedName = nameField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let performers = performersField.stringValue
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
        complete()
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

    /// Writes the shared link to the App Group `Imports/` dir as a
    /// `.tunetroveurl` JSON sidecar (`{ url, name, performers, autosave }`); the
    /// app resolves it to a `music-catalog:` recording. The filename is incidental
    /// (the app reads the contents), so it's fixed.
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

    // MARK: - Shared helpers

    /// Builds the destination filename. Prefers `suggestedName`; on Voice Memos
    /// that's nil, so it falls back to the materialized URL's filename (which
    /// carries the recording title) before the generic `shared_audio`.
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

    /// Writes the audio bytes into the App Group; returns the destination URL
    /// (the form keys its sidecar to it), nil on error.
    private func write(data: Data, name: String) -> URL? {
        guard let dir = importsDir() else { return nil }
        let dest = unique(in: dir, name: name)
        do {
            try data.write(to: dest)
            return dest
        } catch {
            log.error("write failed: \(error.localizedDescription, privacy: .public)")
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

    /// Shows a one-button alert (sheet if a window exists), then dismisses the
    /// extension. Used for unrecoverable cases (read failure / unsupported link).
    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] _ in self?.cancel() }
        } else {
            cancel()
        }
    }

    private func complete() {
        // Foreground the host app so it drains the App Group inbox immediately,
        // rather than waiting for the user to switch to it manually. macOS lets
        // an extension open a URL via NSWorkspace; the scheme is registered in
        // macos/Runner/Info.plist and handled in AppDelegate.application(_:open:).
        NSWorkspace.shared.open(URL(string: "tunetrove://import")!)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: "com.gcantieni.tuneTrove.ShareExtension", code: 0))
    }
}
