# Share Extension — how audio import works (and how to replicate it)

This documents the **working** macOS Share Extension that imports Apple Voice
Memos (and other audio) into Tune Trove, and how to replicate it for iOS. It was
hard-won; read the "Gotchas" before changing anything.

## End-to-end flow

```
Voice Memos ──Share──▶ ShareExtension.appex ──writes file──▶ App Group container
                                                              group.com.gcantieni.tuneTrove/Imports/
                                                                        │
main app (AudioImportBridge.drainSharedImports) ◀── reads on launch/foreground ──┘
        │  emits SharedAudioFile over a MethodChannel/EventChannel
        ▼
Dart (RecordingListPage) copies into Documents/audio_recordings/, creates a
file:// recording, opens the form. (See ../../ios/ShareExtension/SETUP.md and the
project_audio_import memory.)
```

The extension's only job: get the shared audio bytes and write them into the
**App Group** container. The main app does the rest.

## The working recipe (the part that was hard)

Voice Memos stores recordings as **UUID-named files + a Core Data DB** for
metadata; the title (spaces/emoji/etc.) is display metadata. When sharing, it
vends the audio as a **lazy, security-scoped, in-place file** at a temp staging
path *named after the title* (`…/Containers/com.apple.VoiceMemos/Data/tmp/
TemporaryItems/.com.apple.Foundation.NSItemProvider.<rand>/<title>.m4a`). That
file **does not exist** until you force materialization the right way.

What finally worked (`ShareViewController.importAudio`):

1. Pick the provider's **concrete** audio UTI from `registeredTypeIdentifiers`
   (e.g. `com.apple.m4a-audio`) — never the generic `public.audio`.
2. **`provider.loadObject(ofClass: URL.self)` — this is the key.** It returns a
   URL to an **already-materialized** temp copy that *exists*, e.g.
   `…/Data/tmp/.com.apple.uikit.itemprovider.temporary.<rand>/<title>.m4a`
   (`scoped=true exists=true`). Contrast `loadInPlaceFileRepresentation`, which
   handed back an *unmaterialized* staging path (`exists=false`, "no such file").
   (`canLoadObject(ofClass: URL.self)` was `true`.)
3. `url.startAccessingSecurityScopedResource()` (returns `true`).
4. Read it: `NSFileCoordinator().coordinate(readingItemAt: url,
   options: .forUploading)` + `Data(contentsOf: readURL)`. The file already
   exists from step 2; the coordinated `.forUploading` read is good practice for
   provider-backed files (harmless safety, not the thing that fixed it).
5. Write the bytes into the App Group `Imports/` dir.
6. Filename: use `provider.suggestedName` (the title) and append the extension
   from the UTType (`preferredFilenameExtension`), because `suggestedName` has no
   extension.

Delivery to Dart uses `DispatchGroup`: only call
`extensionContext.completeRequest` after every provider's completion handler has
fired, so the extension isn't torn down mid-read.

## What did NOT work (don't re-try these for Voice Memos)

| Approach | Result |
|---|---|
| `loadItem(forTypeIdentifier:)` | returns a URL, `copyItem` → "no such file" |
| `loadFileRepresentation(forTypeIdentifier:)` | "Cannot load representation of type com.apple.m4a-audio" |
| `loadDataRepresentation(forTypeIdentifier:)` | "Cannot load representation" (it's a file-backed rep, not raw data) |
| `loadInPlaceFileRepresentation` + `NSFileCoordinator options: []` | URL with `scoped=true exists=false`, read "no such file" |
| `loadDataRepresentation(forTypeIdentifier: "public.audio")` | silent nil — load*Representation matches the **exact** registered id, not a conforming parent |

The winner is **`loadObject(ofClass: URL.self)`** — it yields a URL to a file
that *actually exists* (a UIKit item-provider temp copy), where every
`load*Representation` path handed back something unreadable.

## Diagnosing (when it breaks again)

Logs use `os.Logger` subsystem `com.gcantieni.tuneTrove.ShareExtension` at
**`.notice`** (Console hides `.info` by default — that cost us an hour). In
Console.app, filter on `tuneTrove`. The introspection line is the most useful:

```swift
"name=\(p.suggestedName) data=[\(p.registeredTypeIdentifiers)] \
 inPlace=[\(p.registeredTypeIdentifiers(fileOptions: .openInPlace))] \
 canURL=\(p.canLoadObject(ofClass: URL.self))"
```
For a Voice Memo this prints:
`data=[com.apple.m4a-audio,public.utf8-plain-text,public.file-url] inPlace=[] canURL=true`.

(The verbose logging can be trimmed to errors once you trust it.)

## Project / Xcode setup — maintenance gotchas

- **Do NOT delete & recreate the target.** Recreating regenerates Xcode's
  template files (a stock `ShareViewController.swift`, a `MainInterface.storyboard`,
  an `Info.plist` with `TRUEPREDICATE`) that silently overwrite ours. If you must,
  re-apply: our `ShareViewController.swift`, the `Info.plist` (below), and delete
  any generated `.storyboard`/`.xib`.
- **Target must be a macOS target.** A target accidentally created from the
  *iOS* template builds an iOS `.appex` (lands in `Debug-iphoneos/`) and fails
  `import Cocoa`; symptom is the host's embed phase erroring "ShareExtension.appex
  … no such file". Base SDK must be macOS.
- **Embed under Runner:** Runner target → Build Phases → a Copy Files phase
  (Destination *PlugIns and Foundation Extensions*) containing
  `ShareExtension.appex`, exactly once (duplicates → "Cycle inside Runner").
- **Bundle id** must be prefixed by the host app: `com.gcantieni.tuneTrove.ShareExtension`.
- **Display name:** set General → Display Name = `Tune Trove` (else the share
  sheet shows "ShareExtension").
- **Capabilities:** App Sandbox ON; App Groups `group.com.gcantieni.tuneTrove` on
  **both** Runner and the extension. (`com.apple.security.application-groups` —
  NOT the hallucinated `com.apple.developer.app-groups`.) The extension also has
  `com.apple.security.files.user-selected.read-only`.
- **Info.plist** (`macos/ShareExtension/Info.plist`): minimal —
  `NSExtensionPointIdentifier = com.apple.share-services`,
  `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).ShareViewController` (NO
  storyboard key), and an **audio-only** `NSExtensionActivationRule`
  (`UTI-CONFORMS-TO "public.audio"`) — not `TRUEPREDICATE`.

## Replicating for iOS

The shared bits already exist: `ios/Runner/AudioImportBridge.swift` (cross-platform,
drains the App Group), the App Group on the iOS Runner, and `ios/ShareExtension/`
(target created, `Info.plist` with principal class + audio rule, entitlements with
the app group). What remains for iOS:

1. **Make iOS `ShareViewController` use this same recipe.** It currently uses
   `loadFileRepresentation`; switch it to the `loadObject(URL)` +
   `NSFileCoordinator .forUploading` approach above (replace `import Cocoa` /
   `NSViewController` with `import UIKit` / `UIViewController`; everything else —
   concrete UTI, security scope, coordinator, App Group write, `suggestedName` —
   is identical). iOS Voice Memos vends the same lazy in-place file, so the plain
   file/data loaders will fail the same way.
2. Confirm the iOS extension is embedded (Embed App Extensions), bundle id
   `com.gcantieni.tuneTrove.ShareExtension`, Display Name `Tune Trove`, App Groups
   on both targets.
3. Test from iOS Voice Memos → Share → Tune Trove; watch Console (filter
   `tuneTrove`) for `urlObject … exists=… → read N bytes → wrote ->`.

Note: on iOS we removed `CFBundleDocumentTypes` so the Share Extension is the
single share entry, and set `FlutterDeepLinkingEnabled=false` so incoming
`file://` URLs don't get routed by go_router.
