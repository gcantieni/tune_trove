# Share Extension setup (iOS + macOS)

These folders (`ios/ShareExtension/`, `macos/ShareExtension/`) hold the source
for the Share Extensions that let Tune Trove appear in the system **Share**
sheet (incl. the Voice Memos "Share" button — the only way to do this on macOS).

The extension copies the shared audio into the **App Group** container; the main
app drains it via `AudioImportBridge.drainSharedImports()` on launch/foreground.

These files are **not yet wired into any Xcode target** — that, and enabling the
App Group capability, are manual steps (capabilities/provisioning can only be set
up in Xcode, never by hand-editing `.entitlements`).

## The only entitlement involved

`com.apple.security.application-groups` — added by Xcode when you turn on the
**App Groups** capability. (The hallucinated `com.apple.developer.app-groups`
does NOT exist — see `.context/playbooks/entitlements.md`.) Group id:
`group.com.gcantieni.tuneTrove`.

## Manual steps — iOS (`ios/Runner.xcworkspace`)

1. **App Group on the app:** select the **Runner** target → Signing &
   Capabilities → **+ Capability → App Groups** → add
   `group.com.gcantieni.tuneTrove`.
2. **Create the extension:** File → New → Target… → **Share Extension** → name
   it `ShareExtension`, language Swift. Let Xcode activate the scheme. This adds
   the target, an embed build phase on Runner, and a generated
   `ShareViewController.swift` + `Info.plist` + `ShareExtension.entitlements`.
3. **Replace the generated files** with the ones in `ios/ShareExtension/`
   (`ShareViewController.swift`, `Info.plist`, `ShareExtension.entitlements`),
   or copy their contents over.
4. **App Group on the extension:** select the **ShareExtension** target →
   Signing & Capabilities → **+ Capability → App Groups** → add the same
   `group.com.gcantieni.tuneTrove`.
5. Build & run on a device/simulator. Voice Memos → a recording → Share → Tune
   Trove. Return to the app; the recording form opens pre-filled.

## Manual steps — macOS (`macos/Runner.xcworkspace`)

1. **App Group on the app:** **Runner** target → Signing & Capabilities → App
   Groups → `group.com.gcantieni.tuneTrove` (this writes the key into both
   `DebugProfile.entitlements` and `Release.entitlements`).
2. **Create the extension:** File → New → Target… → **macOS** tab → **Share
   Extension** → Product Name `ShareExtension`. In the sheet set **Project =
   Runner** and **Embed in Application = Runner**, language Swift. Finish; on
   "Activate scheme?" click **Cancel** (keep the Runner scheme).
3. **If it won't embed under Runner** (the "Embed in Application" picker is empty,
   or the appex doesn't end up in `Runner.app/Contents/PlugIns/`): create the
   target anyway, then embed manually —
   - Select the **Runner** target → **Build Phases**.
   - If there is no copy phase for extensions, click **+ → New Copy Files Phase**.
     Set **Destination = "PlugIns and Foundation Extensions"** (older Xcode:
     "PlugIns"), leave Subpath empty.
   - Click **+** inside that phase → add **ShareExtension.appex**. (This also
     makes Runner depend on the extension so it builds first.)
   - Verify there is exactly **one** such phase containing the appex exactly once
     — duplicates cause "Cycle inside Runner" at build time.
4. **Replace the generated files** with the ones in `macos/ShareExtension/`
   (`ShareViewController.swift`, `Info.plist`, `ShareExtension.entitlements`). If
   Xcode made a `MainInterface.storyboard`, it's unused (we use
   `NSExtensionPrincipalClass`) — delete it or ignore it.
5. **Extension capabilities:** the extension must keep **App Sandbox** ON and add
   **App Groups** (`group.com.gcantieni.tuneTrove`). The provided
   `ShareExtension.entitlements` already lists sandbox + user-selected-read-only +
   the app group.
6. Build & run. Voice Memos (macOS) → Share → Tune Trove. (Reminder: macOS Voice
   Memos still cannot *drag* a recording out — the Share button is the path.)

## Notes

- The main app's `AudioImportBridge.drainSharedImports()` safely no-ops until the
  App Group capability is present (`containerURL(...)` returns nil), so the app
  builds and runs before these steps are done.
- App Group ids must match exactly across the app + both extensions and the
  `appGroupId` constants in `AudioImportBridge.swift` and the two
  `ShareViewController.swift` files.
- Activation is gated to audio (`public.audio`) by the `NSExtensionActivationRule`
  predicate in each `Info.plist`.
