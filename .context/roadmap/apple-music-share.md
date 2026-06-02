# Plan: Ingest Apple Music share links into Recordings

**Goal:** the inverse of the app's MusicKit search-to-recording flow. Today you
search Apple Music *inside* the app to create a recording; this lets you share a
track *from* Apple Music *into* Tune Trove and have it become a recording on the
Recordings page.

**Locked decision:** an ingested share becomes a **`music-catalog:<id>`
Recording** (the same URL form `MusicKitSearchResult.toRecordingUrl()` emits), so
it plays in-app via the existing MusicKit backend — NOT a plain external https URL
recording, NOT an audio file.

## Why this is small (what already exists)
- **Playback:** `audio_player_notifier.dart:26` routes any `music-catalog:`
  trackUri to `musicKitBackendProvider`; `MusicKitBackend.play()` →
  `catalogIdFromUrl()` → native `play`. A stored `music-catalog:<id>` recording
  plays with zero new playback code.
- **Persistence/UI:** `recordingLinkKindOf('music-catalog:…')` already returns
  `RecordingLinkKind.appleMusic` (`library_music` icon, `supportsInAppPlayback`).
  No schema/migration, no new link kind.
- **Surfacing:** `AudioImportController._surfaceForm()` already navigates to
  `/recording_list` on the root navigator and opens
  `showAddRecordingDialog(initialUrl:, initialName:)`, guarded by `_busy`. Reused
  verbatim.
- **Transport:** Share Extension → App Group `Imports/` inbox →
  `AudioImportBridge.drainSharedImports()` → method/event channel → root
  controller, with the `tunetrove://import` foreground hook. Reused.

So the feature reduces to: (a) a pure-Dart **URL parser**
`music.apple.com → catalogId`; (b) a **metadata lookup** by catalog id; (c) a
**URL-aware transport** so a shared https link reaches `AudioImportController`.

## Ground-truth corrections to note
- The service interface is **`MusicKitService`** (provider
  `musicKitServiceProvider`), single method channel
  **`com.gcantieni.tuneTrove/musickit`** for both search and playback — the new
  `lookup` method goes on that channel.
- `kAppleMusicCatalogScheme = 'music-catalog'` and `catalogIdFromUrl` both live in
  `lib/feat/music_kit/music_kit_constants.dart`.

---

## Recommended transport: extend the Share Extension to also accept `public.url`

Options weighed:
- **A. Widen the Share Extension activation rule to `public.url` + write the link
  into the App Group inbox as a sidecar; app drains it through the existing
  `tunetrove://` path. → CHOSEN.** Smallest delta over the just-built pipeline;
  one transport; works on macOS now and iOS once `ios-share.md` lands.
- B. Native Universal Link handling of `https://music.apple.com/...` — rejected:
  needs AASA + entitlement and contends with Apple Music for the domain; the
  share-sheet entry is the natural UX.
- C. Paste / "Add from link" on the Recordings page — kept as an **optional**
  fully-unit-testable fallback (Phase 6) that needs zero native work and de-risks
  the slow native loop, but is not the primary UX.

**Sidecar detail:** the extension writes a tiny text file `<name>.tunetroveurl`
containing the absolute shared URL into `Imports/`. `drainSharedImports()` learns
to recognize `*.tunetroveurl`, read its contents, deliver `{"url":…, "name":…}`
on the existing channel (extra `url` key), then delete it. No second channel; the
audio-file path is untouched.

---

## TDD sequence

`[fast]` = pure Dart under `make test`; `[slow]` = native (`flutter build`/device).
Pure-Dart Phases 1–6 land and fully exercise the feature with mocks before any
native work, mirroring `app-root-import.md`'s "Part B first".

### Phase 1 — URL parser [fast] — the prime TDD target
New `lib/feat/music_kit/apple_music_link.dart`. Write
`test/feat/music_kit/apple_music_link_test.dart` first (table-driven), then
implement:
```dart
String? appleMusicCatalogIdFromShareUrl(String raw); // song catalog id, or null
bool   isAppleMusicShareUrl(String raw);             // recognizable AM web link
String? appleMusicNameFromSlug(String raw);          // slug → "Title Case", or null
```
Rules: `Uri.tryParse`; host endsWith `music.apple.com` (also `beta.`/`geo.`);
album-track form `…/album/<slug>/<albumId>?i=<songId>` → the `i` param; song form
`…/[cc/]song/<slug>/<songId>` → last path segment; locate via the `album`/`song`
keyword (country code is optional); ignore query noise/fragments; bare album with
no `?i=` → null; `playlist`/`artist`/non-AM host/garbage → null; case-insensitive.

### Phase 2 — generalize the shared item [fast]
Widen `SharedAudioFile` (`audio_import_models.dart`) to carry a file path **or** a
url (non-breaking: add nullable `url`, make `path` nullable, assert one is set,
add `bool get isUrl`). `fromMap` prefers `url` when present. Update
`audio_import_models_test.dart` (Red) for the url branch; file branch unchanged.

### Phase 3 — metadata lookup (Dart + mock) [fast Dart / slow native]
Add to `MusicKitService`:
```dart
Future<MusicKitSearchResult?> lookupSong(String catalogId);
```
- `PlatformMusicKitService` → `invokeMethod('lookup', {'catalogId': id})` →
  `MusicKitSearchResult.fromMap`, null on null/error.
- `MockMusicKitService` → deterministic fake (echo id, e.g. title
  `'The Morning Dew'`), and **null for a sentinel id `'unknown'`** to exercise the
  not-found path.
New `test/feat/music_kit/mock_music_kit_service_test.dart` (Red) for the contract.

### Phase 4 — ingest logic in AudioImportController [fast]
Inject `MusicKitService` (provider passes `ref.read(musicKitServiceProvider)`).
Branch `_handleSharedFile` on `item.isUrl`:
```dart
Future<void> _handleSharedUrl(String url, String fallbackName) async {
  final catalogId = appleMusicCatalogIdFromShareUrl(url);
  if (catalogId == null) { _surfaceForm(url: url, name: fallbackName); return; }
  final recordingUrl = '$kAppleMusicCatalogScheme:$catalogId';
  var name = fallbackName;
  try {
    final meta = await _musicKit.lookupSong(catalogId);
    name = meta != null
        ? (meta.artistName.isEmpty ? meta.title : '${meta.title} — ${meta.artistName}')
        : (appleMusicNameFromSlug(url) ?? fallbackName);
  } catch (_) { name = appleMusicNameFromSlug(url) ?? fallbackName; }
  _surfaceForm(url: recordingUrl, name: name);
}
```
`_busy`, `_surfaceForm`, navigation, resume drain — unchanged. Graceful
degradation: unavailable/unauthorized MusicKit → slug-derived name; non-AM URL →
plain recording with the raw URL.

### Phase 5 — end-to-end Dart flow test [fast]
New `test/apple_music_ingest_flow_test.dart` (modeled on
`audio_import_flow_test.dart`, root-controller harness + real router): override
`audioImportServiceProvider`=Mock and `musicKitServiceProvider`=Mock; `emit` a
`SharedAudioFile(url: '<album-track URL>')`; assert the form opens prefilled with
`music-catalog:<songId>` and the mock-resolved name. Cases: AM song URL →
catalog recording; non-AM URL → raw-URL recording (no crash); two rapid emits →
exactly one form (`_busy`).

### Phase 6 — optional "Add from link" affordance [fast]
Small button in `add_recording_dialog.dart` / `recording_list_page.dart` that
reads the clipboard, runs the parser, and prefills the form. Pure-Dart,
widget-testable; makes the feature usable on desktop without the extension.

### Phase 7 — macOS Share Extension URL branch [slow]
1. `macos/ShareExtension/Info.plist`: widen `NSExtensionActivationRule` to OR the
   existing audio subquery with a `public.url` subquery (keep it a SUBQUERY
   predicate — never `TRUEPREDICATE`, per SHARE_EXTENSION.md).
2. `macos/ShareExtension/ShareViewController.swift`: if no audio provider but a
   `public.url` provider, `loadObject(ofClass: URL.self)`; if host is
   `music.apple.com`, write `<name>.tunetroveurl` into the App Group `Imports/`,
   then `complete()` (already opens `tunetrove://import`).
3. `ios/Runner/AudioImportBridge.swift` (shared by the macOS target):
   `drainSharedImports()` handles `*.tunetroveurl` — read contents, deliver
   `{"url":…, "name":…}` via the existing `eventSink`/`pendingFile`, then delete.
   Add a sibling `handleSharedUrlFile(_:)`; `handleIncomingURL` stays file-only.
Verify `flutter build macos`.

### Phase 8 — iOS Share Extension URL branch [slow, gated on ios-share.md]
Mirror Phase 7 in `ios/ShareExtension/*`. The URL branch is simpler than the
audio one (a plain web URL `loadObject(URL.self)` has no Voice-Memo
materialization problem), but it rides the same embed/bundle-id/App-Group setup
that `.context/roadmap/ios-share.md` has not yet device-verified. Land the code;
flag iOS end-to-end as blocked on that.

### Phase 9 — native metadata lookup [slow]
Add `case "lookup"` to the MusicKit bridge Swift (one shared source compiled into
both targets; find via grep for the `com.gcantieni.tuneTrove/musickit` handler /
`MusicCatalogResourceRequest`). Reuse the exact request the play path already
uses: `MusicCatalogResourceRequest<Song>(matching: \.id, equalTo:
MusicItemID(catalogId))`, return `{kind,id,title,artistName,albumTitle,
durationMs,artworkUrl}` (null if not found), gated behind authorization like
search. Verify `flutter build ios`/`macos`.

---

## New / changed files
**New:** `lib/feat/music_kit/apple_music_link.dart`;
`test/feat/music_kit/apple_music_link_test.dart`;
`test/feat/music_kit/mock_music_kit_service_test.dart`;
`test/apple_music_ingest_flow_test.dart`.
**Changed (Dart):** `audio_import_models.dart` (+`url`/`isUrl`);
`audio_import_controller.dart` (URL branch + inject `MusicKitService`);
`music_kit_service.dart` / `platform_music_kit_service.dart` /
`mock_music_kit_service.dart` (`lookupSong`); `audio_import_models_test.dart`;
(optional) `add_recording_dialog.dart` / `recording_list_page.dart`.
**Changed (native):** `macos/ShareExtension/{Info.plist,ShareViewController.swift}`;
`ios/ShareExtension/{Info.plist,ShareViewController.swift}`;
`ios/Runner/AudioImportBridge.swift` (sidecar drain); MusicKit bridge Swift
(`case "lookup"`).
**No** `recordings.dart`/DAO/migration changes; **no** new `RecordingLinkKind`.

## Unit tests (literal cases)
**Parser:**
`…/us/album/cold-blow/123?i=789`→`789`; `…/gb/album/x/1?i=2`→`2`;
`…/us/song/the-morning-dew/789`→`789`; `…/song/x/789` (no cc)→`789`;
`…/jp/album/foo/1?i=2&l=en`→`2`; `…/us/album/x/123` (no `?i=`)→`null`;
`…/us/playlist/foo/pl.1`→`null`; `…/us/artist/x/3`→`null`;
`open.spotify.com/track/abc`→`null`; `example.com/us/song/x/1`→`null`;
`'not a url'`/`''`→`null`; `…/album/x/1?i=2#t=30`→`2`; uppercase host/path→id;
`beta.music.apple.com/us/song/x/9`→`9`.
`isAppleMusicShareUrl`: true for all `music.apple.com` rows (incl. album/playlist),
false otherwise. `appleMusicNameFromSlug`: `…/song/the-morning-dew/1`→
`The Morning Dew`; `…/album/cold-blow-and-the-rainy-night/1?i=2`→
`Cold Blow And The Rainy Night`; non-AM→`null`.
**Model:** `fromMap({'url':…,'name':'X'})`→`isUrl`; `fromMap({'path':…})`→file;
`fromMap({})`→null. **Mock:** `lookupSong('789')`≠null; `lookupSong('unknown')`==null.
**Flow:** the three cases in Phase 5.

## Acceptance tests (manual)
**macOS (Phase 7+9):** Apple Music (or music.apple.com in Safari) → song → Share →
Tune Trove → app foregrounds, navigates to Recordings, form prefilled with
`music-catalog:<id>` + "Title — Artist"; Save → row shows `library_music` icon →
tap play → plays in-app. Console filter `tuneTrove` shows the sidecar drain + the
`lookup` resolve.
**iOS (Phase 8+9, gated on ios-share.md):** Apple Music app → Share → Tune Trove →
same outcome; watch Console.
**Desktop fallback (Phase 6):** paste a `music.apple.com` link via "Add from link"
→ form prefills `music-catalog:<id>` → Save → plays.

## Risks / unknowns to confirm on device
- Whether `MusicCatalogResourceRequest` resolves catalog metadata **without full
  sign-in**. If not, the slug-name fallback keeps the feature working (recording
  still created and playable once authorized).
- Storefront/region stability of the `?i=` id vs the user's storefront (play path
  uses the raw id, so parity with search-created recordings is expected).
- Whether Apple Music's share sheet actually vends a `public.url` attachment to a
  third-party extension, and that the widened activation predicate fires for it
  without over-activating (we host-filter `music.apple.com` in code regardless).
- Album shares (no `?i=`) currently fall back to a generic-URL recording — confirm
  that's desired vs rejecting with a snackbar.
- iOS host-launch + iOS share extension are blocked on `ios-share.md`
  device verification.
