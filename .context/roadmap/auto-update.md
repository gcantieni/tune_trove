# Roadmap: Push-driven auto-update (real-time sync)

## Background

Today sync only runs when something *triggers* it: app launch, the manual "Sync
Now" button, pull-to-refresh, or a local mutation (which stages + pushes). A
change made on device A does **not** appear on device B until B triggers a sync.

Why pushes don't flow today (all confirmed in the current code):

1. **No CloudKit subscription is registered** — the rewritten
   `ios/Runner/CloudKitSyncBridge.swift` dropped the old
   `setupDatabaseSubscription`, so CloudKit has no reason to send a push.
2. **No remote-notification registration or handlers** — neither
   `ios/Runner/AppDelegate.swift` nor `macos/Runner/AppDelegate.swift` calls
   `registerForRemoteNotifications()` or implements `didReceiveRemoteNotification`.
3. **No background mode** — `ios/Runner/Info.plist` has no `UIBackgroundModes`
   (`remote-notification`).
4. **`automaticallySync = false`** — the engine deliberately doesn't self-manage
   pushes/fetches; sync is Dart-driven and deterministic.

`aps-environment` *is* already present in all entitlement files, so the push
entitlement itself is in place.

## Goal

When device A changes data, device B's open lists update within a few seconds
**without a manual pull**. Phase 1 targets the foreground case (app open on B);
background updates are a harder, separate phase.

## Recommended approach: push as a trigger (keep the deterministic model)

Keep `automaticallySync = false` and the existing
`fetchChanges → reconcile → send` flow. Use a CloudKit silent push purely as a
*nudge*: when it arrives, tell Dart to run the sync it already knows how to run.
Lists then update reactively through the Drift `watch` streams that
reconciliation writes feed.

This reuses everything (`SyncOutboundService.syncNow`,
`SyncReconciliationService`, dedupe, the `SyncStager` send path) and avoids the
alternative's downsides (below).

### Alternative considered — flip `automaticallySync = true`

The engine would auto-subscribe, auto-fetch on push, and deliver inbound records
via the delegate at arbitrary times. That means re-introducing EventChannel-based
inbound reconciliation (the dual-path + ordering races the deterministic model
was built to avoid) and losing the "`fetchChanges` returns the result" contract.
Bigger re-architecture; not recommended for the first cut.

## Phase 1 — foreground near-real-time

1. **Register a subscription** (`CloudKitSyncBridge`): create a silent
   `CKDatabaseSubscription` (`shouldSendContentAvailable = true`,
   `shouldBadge/Alert/Sound = false`) on the private DB with a stable
   subscriptionID, once. Guard with a persisted flag (engine state file or
   `UserDefaults`) so it isn't re-saved every launch. Call it from
   `initializeEngine()`. Confirm it doesn't collide with the engine (it won't,
   since `automaticallySync = false`).
2. **Capabilities / Info.plist**: add **Background Modes → Remote notifications**
   (`UIBackgroundModes = [remote-notification]`) to `ios/Runner/Info.plist`; the
   macOS target needs the equivalent push capability. `aps-environment` already
   exists.
3. **Register for remote notifications**:
   - iOS `AppDelegate`: `application.registerForRemoteNotifications()` after
     launch; implement `didRegisterForRemoteNotificationsWithDeviceToken`
     (no-op/log — CloudKit uses the token via APNs automatically) and
     `didFailToRegisterForRemoteNotificationsWithError`.
   - macOS `AppDelegate`: `NSApplication.shared.registerForRemoteNotifications()`
     plus the `NSApplicationDelegate` equivalents.
4. **Receive push → emit to Dart**:
   - iOS: `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` →
     build `CKNotification(fromRemoteNotificationDictionary:)`, verify it's ours
     (container + subscriptionID) → forward to the bridge.
   - macOS: `application(_:didReceiveRemoteNotification:)`.
   - Bridge: add `emitRemoteChange()` that sends a new EventChannel payload
     `{"type": "remoteChange"}` (the channel currently carries only `status`).
5. **Dart reacts**: `PlatformCloudKitSyncService` parses `remoteChange` into a
   `Stream<void> get remoteChanges`. A small startup listener (in `SyncStager` or
   a dedicated provider watched in `main.dart`) triggers a **fetch + reconcile**
   on each event, debounced/coalesced.
   - **Open decision — snackbar or silent?** A push-triggered sync popping
     "Syncing from iCloud" while the user is just reading would be noisy.
     Recommend a *silent* fetch+reconcile path (don't route through
     `SyncNotifier`'s snackbar phases) — or a subtle indicator only. Pull-to-
     refresh and launch keep their snackbars.

## Phase 2 — background updates (app not foreground)

Harder; assess after Phase 1 ships. A content-available push wakes the app with
limited background time via `didReceiveRemoteNotification:fetchCompletionHandler:`,
and the completion handler must be called with the right
`UIBackgroundFetchResult`. The wrinkle: reconciliation is **Dart** code, so the
Flutter engine must run and finish the fetch+reconcile within the background
window, then signal completion. Options to evaluate: drive the whole cycle from
the headless engine, or fetch natively and defer reconcile to next foreground.
Document findings before committing.

## Tradeoffs / open questions

- **Simulator unreliable**: APNs/CloudKit pushes are flaky on the iOS Simulator
  — verify on a real device. macOS needs the app properly signed + APNs reachable.
- **Coalescing**: multiple rapid pushes should collapse into one fetch (debounce).
- **Subscription lifecycle**: re-create if the account changes
  (`.accountChange` already observed by the bridge).
- **`CKError` on subscription save**: handle "already exists" idempotently
  (mirror how zone creation is treated).

## Verification

- Two devices on one iCloud account. Device A adds a set; device B with the app
  **foregrounded** updates within a few seconds with no manual pull.
- Confirm the subscription appears in CloudKit Console (Development →
  Subscriptions) for `iCloud.com.gcantieni.tuneTrove`.
- Test on a **real device**, not the simulator.
- Regression check: manual "Sync Now", launch sync, and pull-to-refresh still
  behave as before.
