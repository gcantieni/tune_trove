# Plan: app-root audio import + auto-foreground on share

**Goal:** two related improvements to the share→import flow:
1. **Auto-open the app** when the user shares to Tune Trove (today the extension
   writes the file but the app must be manually foregrounded for the drain to run).
2. **Move receiving to the app root** so a shared file is absorbed responsively on
   *any* tab — not only while `RecordingListPage` is mounted. (Files still *land*
   in Recordings; only the *receiving/listening* becomes global.)

**Decisions already made (user):**
- iOS auto-open: **include the responder-chain openURL workaround** (no official
  API exists; widely used, works today, unofficial — flag it in code comments).
- Surface UX: on a shared file, **navigate to the Recordings tab and open the
  prefilled add-recording form**.

## Read first
- `macos/ShareExtension/SHARE_EXTENSION.md` — how the extension + App Group +
  drain work (the receiving mechanism this builds on).
- `IOS_SHARE.md` — the *separate, independent* task of fixing the iOS extension's
  file read. **This refactor does not depend on it and vice-versa.**
- Memory: `project_audio_import`.
- Key files: `lib/feat/recording_list/recording_list_page.dart` (current owner of
  the listener/observer/import — to be slimmed), `lib/feat/audio_import/*`,
  `lib/main.dart`, `lib/routing/app_router.dart` (root navigator key + NavScaffold
  shell), `ios/Runner/SceneDelegate.swift`, `ios/Runner/AudioImportBridge.swift`,
  `macos/Runner/AppDelegate.swift`, `macos/ShareExtension/ShareViewController.swift`,
  `ios/ShareExtension/ShareViewController.swift`, both `Runner/Info.plist`.

## Do Part B first (pure Dart, fast loop, no device). Then Part A.

---

## Part B — Move receiving from the page to the app root

Today `RecordingListPage` (a `ConsumerStatefulWidget` + `WidgetsBindingObserver`)
owns: the `incomingFiles` subscription, `takeInitialSharedFile()` on init, the
resume re-drain, and `_handleSharedFile` (copy + open prefilled form). Lift all of
it to a single app-root owner.

1. **New `AudioImportController`** — `lib/feat/audio_import/audio_import_controller.dart`
   (+ a provider). Owns:
   - `incomingFiles` subscription,
   - `takeInitialSharedFile()` at startup,
   - the `WidgetsBindingObserver` resume re-drain (moved off the page),
   - the import action: `copyIntoAudioStore(file.path, file.name)` →
     `'file://$destPath'` → surface the prefilled form.
   - It must be lifecycle-long (app root), and idempotent/guarded against
     double-handling (e.g. don't re-open a form if one is already open).
2. **Surface UI from root via go_router.** Check `lib/routing/app_router.dart` for
   the existing root `navigatorKey` (the NavScaffold shell uses one). On a shared
   file: navigate to the Recordings route, then open the prefilled
   `RecordingFormWidget`. Extract the current `_showAddRecordingDialog` body from
   `recording_list_page.dart` into a reusable helper (e.g. in the recording_list
   feature) that both the page FAB and the controller call.
   - Use the router (`goRouter.go('/recording_list')` or equivalent) + the root
     navigator context to show the dialog, so it works regardless of active tab.
3. **Start the controller once at app root** — in `main.dart` (or a thin root
   `ConsumerStatefulWidget` wrapping `MaterialApp.router`). `ref.watch` it so it's
   constructed for the whole app lifetime; dispose cleanly.
4. **Slim `RecordingListPage`** — remove the subscription, the observer, and
   `_handleSharedFile`; keep only page-specific UI (FAB → shared add-recording
   helper).

**This alone removes the "only drains where the listener lived" limitation** — even
without auto-open, sharing then returning to the app imports from any tab.

### Part B tests (front-load)
- Adapt `test/audio_import_resume_test.dart` to drive the **root controller**
  instead of the page: emit/enqueue a `SharedAudioFile` via
  `MockAudioImportService` → assert copy-into-store + prefilled
  `RecordingFormWidget` appears.
- **New core test:** file shared while on a **non-Recordings route** still imports
  (controller navigates + opens form). This is the behavior change.
- Keep `make test` green; `make analyze` clean.

---

## Part A — Auto-foreground the app on share (custom URL scheme)

The extension writes to the App Group but never launches the host. Have it open a
custom URL after writing; the host catches it and drains immediately.

1. **Register a URL scheme** `tunetrove` (`CFBundleURLTypes`) in BOTH
   `ios/Runner/Info.plist` and `macos/Runner/Info.plist`. Use e.g.
   `tunetrove://import`. (`FlutterDeepLinkingEnabled=false` is already set, so this
   URL won't leak into go_router.)
2. **Extensions open it in `complete()`**, after the file is written:
   - **macOS** (`macos/ShareExtension/ShareViewController.swift`): supported and
     clean — `NSWorkspace.shared.open(URL(string: "tunetrove://import")!)`.
   - **iOS** (`ios/ShareExtension/ShareViewController.swift`): ⚠️ **no official API**
     for a share extension to launch its host. Use the responder-chain workaround:
     walk `self` up via `next` until a `UIApplication` is found, then call
     `open(_:options:completionHandler:)` (older selector-based variants use
     `openURL:`). **Comment it heavily** as unofficial/gray-area. Call it right
     before `completeRequest`.
   - Heads-up: this couples the (currently UIKit-port-pending) iOS extension with
     `IOS_SHARE.md`. The iOS auto-open only matters once the iOS extension actually
     reads the file — fine to land the code, but it's only testable after
     `IOS_SHARE.md` is done.
3. **Host catches the scheme → drains.** Plumbing exists:
   - iOS `SceneDelegate.handle(_:)` currently `guard url.isFileURL`. Add: if
     `url.scheme == "tunetrove"` → `AudioImportBridge.shared?.drainSharedImports()`
     (and return; don't treat as a file).
   - macOS `AppDelegate.application(_:open:)` — same branch.
   - Result: app foregrounds → drain runs → bridge emits on the channel → the
     **root** `AudioImportController` (Part B) handles it → navigates + opens form.
     Note this is why Part B should land first: the root listener is what makes the
     auto-opened app actually do something useful immediately.

### Part A verification (device/desktop, slow — do after B is green)
- **macOS:** Voice Memos → Share → Tune Trove → app comes to front and the
  prefilled form appears (Recordings). No manual switch.
- **iOS:** only after `IOS_SHARE.md`. Voice Memos → Share → Tune Trove → app opens
  to the prefilled form. Watch Console (`tuneTrove`) for the scheme open + drain.

## Sequencing summary
1. **Part B** (Dart + tests) — independent, fast, removes the tab limitation.
2. **Part A macOS** — fully supported, verify on desktop.
3. **Part A iOS** — land the (commented, unofficial) openURL hook; only end-to-end
   testable once `IOS_SHARE.md` lands.

## Watch out for
- Don't reintroduce `CFBundleDocumentTypes` on iOS or flip
  `FlutterDeepLinkingEnabled` back on (causes `GoException: no routes for
  location: file://…`). The custom scheme is handled natively, not by go_router.
- Guard against double-import / double-form (cold-launch `takeInitialSharedFile`
  + a near-simultaneous `incomingFiles` event + a `tunetrove://` drain can all
  fire close together). De-dupe in the controller.
- App Group id must stay `group.com.gcantieni.tuneTrove` across all targets.
- No CocoaPods (SPM-only).
- The iOS responder-chain openURL is the one genuinely risky/unofficial piece —
  keep it isolated and clearly commented so it's easy to rip out if Apple breaks it.
