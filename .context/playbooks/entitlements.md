# Entitlements

## The core rule

If a capability does not appear in **Xcode → Signing & Capabilities**, it is almost certainly not a real entitlement. The feature is either:

- Available to all apps (no gate at all), or
- Controlled by an `Info.plist` key, or
- An **App Service** enabled via the Apple Developer portal — no entitlement, no presence in the code signature.

Claiming a non-existent entitlement in a `.entitlements` file breaks code signing. Xcode cannot create a provisioning profile that authorises a key it doesn't recognise.

## How to verify an entitlement is real

1. Try adding the capability in Xcode's Signing & Capabilities editor. If it's not listed there, it is likely not an entitlement.
2. Search Apple's official documentation: **Bundle Resources › Entitlements**.
3. Do not rely on AI suggestions, third-party forums, or non-Apple sources for entitlement key names.

## MusicKit and ShazamKit (relevant to this project)

`com.apple.developer.musickit` and `com.apple.developer.shazamkit` **do not exist** as entitlements.

Both are **App Services** — enabled on the Apple Developer portal under **Identifiers → \<App ID\> → App Services**, with no code-signature footprint. Do not add either key to any `.entitlements` file.

To enable MusicKit for this app:
1. Developer portal → Identifiers → `com.gcantieni.tuneCatcher` → enable **MusicKit** under App Services → Save.
2. Clean the Xcode build folder to regenerate provisioning profiles.

## macOS sandbox: saving the backup file

The backup export uses a native **Save** panel on macOS (file_picker). Writing to
a user-chosen location requires the **read-write** user-selected files
entitlement, not read-only:

```
com.apple.security.files.user-selected.read-write   (true)
```

This replaced `…user-selected.read-only` in both
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`. Symptom of
the read-only form: `PlatformException(ENTITLEMENT_REQUIRED_WRITE, The Read-Write
entitlement is required for this action.)`. read-write is a real, Xcode-listed
entitlement (App Sandbox → File Access → User Selected File → Read/Write) and
supersedes read-only.

## Common hallucinated entitlements

| Hallucinated key | Reality |
|---|---|
| `com.apple.developer.musickit` | App Service (no entitlement) |
| `com.apple.developer.shazamkit` | App Service (no entitlement) |
| `com.apple.developer.push-notifications` | Correct key: `aps-environment` |
| `com.apple.developer.in-app-purchase` / `com.apple.InAppPurchase` / `com.apple.developer.storekit` | No entitlement; available to any app with an explicit App ID |
| `com.apple.developer.app-groups` | Correct key: `com.apple.security.application-groups` |
| `com.apple.developer.background-modes` / `UIBackgroundModes` (as entitlement) | Correct location: `UIBackgroundModes` in `Info.plist` |
| `com.apple.developer.family-controls.user-authorization` | Correct key: `com.apple.developer.family-controls` |
| `com.apple.developer.nearby-interaction` | No entitlement needed |
| `com.apple.developer.secure-enclave` | No entitlement on iOS; macOS: access via data protection keychain |
| `com.apple.developer.networking.configuration` | Correct key: `com.apple.developer.networking.HotspotConfiguration` |
| `com.apple.security.accessibility` | No entitlement; user grants in System Settings |
| `com.apple.developer.adservices` | No entitlement needed |

## Source

Quinn "The Eskimo!" (Apple DTS) — https://developer.apple.com/forums/thread/799000 (last updated 2026-04-23)
