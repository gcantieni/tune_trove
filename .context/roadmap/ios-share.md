# Plan: iOS Share Extension — import Voice Memos into Tune Trove

**Goal:** make sharing an audio file (esp. an Apple Voice Memo) from iOS into
Tune Trove actually import it — by porting the **proven macOS recipe** to the iOS
Share Extension. The macOS version works end-to-end; this is mostly a mechanical
UIKit port, but iOS has a few traps and a *much slower* debug loop, so work
deliberately.

## Read these first
- **`macos/ShareExtension/SHARE_EXTENSION.md`** — the working recipe, the list of
  approaches that DON'T work, the diagnosing notes, and Xcode maintenance
  gotchas. This is the source of truth; the iOS code should mirror it.
- `macos/ShareExtension/ShareViewController.swift` — the **reference
  implementation** to copy from (NSViewController/Cocoa → port to
  UIViewController/UIKit).
- `ios/ShareExtension/ShareViewController.swift` — the file to rewrite (currently
  uses `loadFileRepresentation`, which will fail the same way it did on macOS).
- `ios/ShareExtension/Info.plist`, `ios/ShareExtension/ShareExtension.entitlements`,
  `ios/ShareExtension/SETUP.md`.
- `ios/Runner/AudioImportBridge.swift` — cross-platform bridge; already drains the
  App Group `Imports/` dir on launch + `didBecomeActive`. **No changes expected.**
- Dart side (no changes expected, already tested): `lib/feat/audio_import/*`,
  `lib/feat/recording_list/recording_list_page.dart` (resume re-drain),
  `lib/feat/recording_list/recording_file_store.dart`.
- Memory: `project_audio_import` (in the auto-memory dir) — summary + status.

## Current iOS state
- The iOS Share Extension **target already exists** and is embedded under Runner
  (the "Cycle inside Runner" issue was already fixed — do NOT recreate the
  target; recreating regenerates template files that overwrite ours).
- App Group `group.com.gcantieni.tuneTrove` is on the iOS Runner AND the extension
  entitlements. `Info.plist` already has `NSExtensionPrincipalClass =
  $(PRODUCT_MODULE_NAME).ShareViewController` + an audio-only
  `NSExtensionActivationRule` (no storyboard).
- `ios/Runner/Info.plist` has `FlutterDeepLinkingEnabled=false` and **no**
  `CFBundleDocumentTypes` (single clean Share-Extension entry — don't re-add it).
- **What's wrong:** `ios/ShareExtension/ShareViewController.swift` uses
  `loadFileRepresentation`. iOS Voice Memos vends the same lazy, security-scoped
  in-place file as macOS, so this almost certainly fails ("no such file" /
  "cannot load representation"). It has never been confirmed to import via the
  extension path.

## The change (one file)
Rewrite `ios/ShareExtension/ShareViewController.swift` to the macOS recipe, UIKit
variant:
- `import UIKit` (+ `UniformTypeIdentifiers`, `os`); `class ShareViewController:
  UIViewController`. (UIViewController creates its own view, so no `loadView`
  nib-avoidance dance is needed; just `view.backgroundColor = .clear` in
  `viewDidLoad` and call the import.)
- Same logic as macOS `importAudio`: pick the **concrete** audio UTI from
  `registeredTypeIdentifiers` → `loadObject(ofClass: URL.self)` →
  `startAccessingSecurityScopedResource()` → `NSFileCoordinator` read with
  `options: .forUploading` → write into the App Group `Imports/` dir →
  `extensionContext.completeRequest`, gated by a `DispatchGroup`.
- Filename from `suggestedName` + UTType `preferredFilenameExtension`.
- **iOS memory tweak:** prefer `FileManager.copyItem(at: readURL, to: dest)` over
  `Data(contentsOf:)` + write. iOS extensions have a tight memory budget
  (historically ~120 MB) and a long memo loaded fully into RAM can be killed;
  `copyItem` streams. (macOS used `Data(contentsOf:)`; on iOS use copyItem.)
- **Keep the verbose `.notice` diagnostic logging IN for the first device test**
  (the `name=… data=[…] inPlace=[…] canURL=…` line + per-step traces), exactly
  like macOS. iOS Voice Memos *may* vend differently — don't assume `canURL=true`.
  Confirm from the device log, then strip logging in a follow-up once it imports.

## iOS-specific things to watch out for
- **UIKit, not Cocoa.** `UIViewController`, `UIView`. Don't copy `NSViewController`/
  `loadView`/`NSView` from macOS.
- **Don't assume the loader.** Run the diagnostic first; if iOS shows
  `canURL=false` or different `data=[…]`, pick the loader per
  SHARE_EXTENSION.md's decision tree rather than forcing `loadObject(URL)`.
- **Entitlements differ from macOS.** The iOS extension entitlements should be
  just `com.apple.security.application-groups` (NO macOS sandbox /
  `files.user-selected.read-only` keys). Verify it wasn't regenerated.
- **Security scope** may be a no-op on iOS (the URL is often a temp copy);
  `startAccessingSecurityScopedResource()` returning false is fine — keep the
  call, it's harmless.
- **Bundle id / display name:** extension bundle id must be
  `com.gcantieni.tuneTrove.ShareExtension`; set Display Name = `Tune Trove` (else
  the share sheet shows "ShareExtension").
- **Don't reintroduce** `CFBundleDocumentTypes` or flip `FlutterDeepLinkingEnabled`
  back on (causes the `GoException: no routes for location: file://…`).
- **No CocoaPods** (SPM-only project) — nothing to add; the extension uses only
  system frameworks.
- **Warm-share scope limitation** (same as macOS): the Dart drain listener lives
  on `RecordingListPage`, so an import surfaces when that tab is mounted/resumed.
  Out of scope here; note only.

## Testing strategy — the iOS loop is SLOW, so front-load everything
The device build+deploy+share+Console cycle is minutes each. Minimize round trips:
1. **Think first.** Diff the iOS `ShareViewController` against the working macOS one
   line by line; the only legitimate differences are UIKit types + `copyItem`.
   Getting it byte-faithful to the proven version is the best risk reduction.
2. **Run the Dart suite:** `make test` (the import pipeline, resume re-drain, and
   `file://` URL behavior are already covered there — keep them green).
3. **Extract + unit-test pure logic where possible.** The filename/extension
   derivation and the unique-name collision logic are pure functions; consider
   lifting them so they can be exercised by `ios/RunnerTests` (or at least keep
   them tiny and obviously correct). NSItemProvider/share behavior itself can't be
   unit-tested — that's what the single device test is for.
4. **Compile before deploying:** `flutter build ios --debug --no-codesign --no-pub`
   must succeed (catches Swift/UIKit errors without a device). Also watch for
   "Cycle inside Runner" (duplicate embed phase) — see SHARE_EXTENSION.md.
5. **Only then** ask the user to manually test on device. Give them the exact
   Console filter (`tuneTrove`) and the lines to look for.

## Manual verification (hand to the user once 1–4 pass)
1. iOS **Voice Memos → pick a recording → Share → Tune Trove**.
2. In Console.app (device selected, filter `tuneTrove`), expect:
   `… data=[…] … canURL=…` → (loader step) → bytes copied → `Imports/<title>.m4a`.
3. Foreground Tune Trove → **Recordings** tab → the recording imports as a
   `file://` entry and plays.
4. If it fails, the diagnostic line tells which loader iOS needs; adjust per the
   decision tree and repeat (this is why logging stays in for the first pass).

## Done criteria
- Sharing a Voice Memo on iOS imports it (correct title-based filename).
- `make test` green; `flutter build ios --no-codesign` clean.
- Follow-up: strip the verbose `.notice` logging (keep `.error`), mirroring the
  macOS cleanup; update `project_audio_import` memory to mark iOS solved.
