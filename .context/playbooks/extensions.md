# Share Extensions

Tune Trove ships a **Share Extension** on iOS and macOS so the app appears in the
system Share sheet (the only way to get audio out of Voice Memos, and the way
Apple Music links come in). Both present a small native form (Name + Performers),
hand the result to the app via the **App Group**, and the app inserts the
recording. See also [build.md](build.md) and [entitlements.md](entitlements.md).

## Architecture at a glance

```
Source app (Voice Memos / Apple Music)
        │  system Share sheet
        ▼
ShareViewController  (ios/ShareExtension + macos/ShareExtension)
        │  writes into the App Group  group.com.gcantieni.tuneTrove / Imports/
        ▼
AudioImportBridge.drainSharedImports()   (ios/Runner/AudioImportBridge.swift —
        │  cross-platform; runs on launch + every foreground)
        ▼
AudioImportController  (lib/feat/audio_import/) → Drift insert / prefilled form
```

- The extension **never touches the database** (it lives in a separate process
  and the DB is in the app's Documents, not the App Group). It only drops files
  in the App Group inbox; the app does all DB work, so Drift migrations and
  CloudKit sync stay intact (see [migrations](../standards/migrations.md)).
- The bridge, controller, and model are **cross-platform**. Only the two
  `ShareViewController.swift` files are per-OS (UIKit vs AppKit).

## The form flow

`viewDidLoad` inspects the attachments and branches:

- **Audio** (`public.audio`, e.g. a Voice Memo): copy the file into
  `Imports/` in the background (`loadObject(URL)` → security scope →
  `NSFileCoordinator(.forUploading)` → write), prefill Name from the file's title,
  and on **Save** write a `<file>.tunetrovemeta` sidecar.
- **URL** (`public.url`, gated to `music.apple.com`): prefill Name from the link
  slug, and on **Save** write a `shared_link.tunetroveurl` JSON sidecar. The app
  resolves it to a `music-catalog:` recording (MusicKit; see
  `lib/feat/music_kit/apple_music_link.dart`).

A Voice Memo also vends a `public.url` alias, so **audio wins when both are
present**.

### Sidecar contract (App Group `Imports/`)

| File | Contents | Meaning |
|---|---|---|
| `<name>.<ext>` | the audio bytes | the recording file |
| `<name>.<ext>.tunetrovemeta` | `{ "name", "performers" }` | form metadata for the audio above |
| `shared_link.tunetroveurl` | `{ "url", "name", "performers", "autosave" }` | a shared link (iOS/macOS form) |
| `*.tunetroveurl` (plain text) | the bare URL | legacy / non-form link — no `autosave` |

`drainSharedImports()` pairs each audio file with its `.tunetrovemeta`, skips the
meta in the directory scan, and deletes both after draining. The **`autosave`**
flag (set only by the form) tells the controller to insert directly; without it
the prefilled add-recording form is surfaced instead.

### Filename gotcha

The stored audio filename must keep its extension or playback fails
(`-11828 Cannot Open`). The form's Name has no extension, so
`AudioImportController` re-attaches the source file's extension before
`copyIntoAudioStore` — don't pass the bare title as the store filename.

## Save behavior

- **iOS** saves silently (no app launch) — the user stays in the source app; the
  recording appears on the app's next foreground. There is no public API for an
  iOS extension to foreground its host, so don't try.
- **macOS** foregrounds the app on Save via `NSWorkspace.shared.open("tunetrove://import")`
  (registered in `macos/Runner/Info.plist`, handled in the AppDelegate) so the
  drain is immediate.

## Building & deploying

```
make build-ios      # flutter build ios     — embeds ios/ShareExtension as a target dep
make build-macos    # flutter build macos   — embeds macos/ShareExtension
```

The extension compiles as an **embedded dependency of Runner**, so a normal app
build builds it. SourceKit/IDE diagnostics like *"No such module 'UIKit'"* on the
extension files are false positives (they aren't in the indexer's build graph) —
trust the actual `flutter build`.

### iOS deploy gotcha

If the extension fails to compile, Xcode keeps running the **last-good `.appex`**
— so a build error silently leaves the old extension live (symptom: the old
behavior persists, the form never updates). After a failed build, **Clean Build
Folder** and rebuild; confirm the ShareExtension target built with no errors.

## macOS: the registration / shadow trap

macOS resolves Share extensions through Launch Services + PlugInKit and caches
aggressively. The dev build's extension can be **shadowed by another registration
of the same bundle id** (`com.gcantieni.tuneTrove.ShareExtension`), so the share
menu silently invokes the wrong copy and your changes never appear. Two shadows:

1. The shipped **iOS app installed on Apple Silicon** (App Store/TestFlight) at
   `/Applications/Tune Trove.app/Wrapper/Runner.app/PlugIns/ShareExtension.appex`
   — the `Wrapper/Runner.app` layout is the iOS-on-Mac signature.
2. A stale **Release** build under `build/macos/Build/Products/Release/...`.

**Fix:**

```
make reregister-macos          # Debug build (default)
make reregister-macos RELEASE=1
```

It `lsregister -f`s the dev app, `pluginkit -a`s its appex, `pluginkit -r`s every
*other* registration of the bundle id, then `killall sharingd pkd`. Afterward:

- **Relaunch the dev app** (`open build/macos/Build/Products/Debug/tune_trove.app`).
- **Fully quit and reopen the source app** (Voice Memos caches its share menu per
  session — it won't pick up the new extension until relaunched).

Launching the installed iOS-on-Mac app re-registers its extension and re-shadows
the dev build; re-run `make reregister-macos`. Deleting that installed app avoids
the conflict entirely.

### Diagnosing which extension runs

```
pluginkit -m -i com.gcantieni.tuneTrove.ShareExtension -v   # which copy wins
pluginkit -mAv | grep tuneTrove                             # all registrations
log show --last 15m --predicate \
  'subsystem == "com.gcantieni.tuneTrove.ShareExtension"' --info --debug
```

The extensions log only on error. If you need to confirm the dev extension is
actually being invoked, add a temporary `log.notice` in `viewDidLoad` (and strip
it once verified) — no log lines for a share means the dev extension never ran
(it's being shadowed).
