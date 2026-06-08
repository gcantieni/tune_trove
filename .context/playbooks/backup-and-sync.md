# Backup & Sync Transports

The library can leave and re-enter the device through several **sync
transports** — CloudKit (iCloud), a **file/ZIP backup**, and (planned) cloud
drives like Dropbox / Google Drive. They all speak one **canonical record
format** and reconcile through one importer, so a new transport is just a new
sink/source — not a new serializer. See also
[migrations](../standards/migrations.md) and [drift](../standards/drift.md).

## Architecture at a glance

```text
                lib/feat/sync_core/sync_record_codec.dart
   serializeAll(db, {recordTypes})  ◄── single source of truth for the
        │  List<canonical record>        record format (shared by all transports)
        ▼
   SyncTransport.push(records)      lib/feat/sync_core/sync_transport.dart
        ├── CloudKitSyncTransport ── CKSyncEngine bridge (live path still in
        │                            SyncOutboundService; adapter is the seam)
        └── FileSyncTransport ────── ZIP on disk  (lib/feat/backup/)

   import direction:
   transport.pull() → FetchedChanges → SyncReconciliationService.applyFetched
        (cloudId→natural-key dedupe + last-writer-wins; identical for every transport)
```

## The canonical record format

A *record* is a `Map<String, dynamic>` — `recordType`, `cloudId`, snake_case
fields, ms-since-epoch timestamps, enum values as their `.name`. **Join tables
reference their parents by cloud_id**, not local integer id
(`tune_cloud_id`, `recording_cloud_id`, `set_cloud_id`), which is what makes the
format portable across installs. Defined once in
`lib/feat/sync_core/sync_record_codec.dart`:

- `serializeTune` / `serializeRecording` / … — per-row encoders.
- `serializeAll(db, {recordTypes})` — whole-DB snapshot, filtered to the given
  record types.
- `recordsToFetchedChanges(records)` — wraps records as all-upserts so any
  transport's `pull()` can feed reconciliation.

Inbound, `SyncReconciliationService` (`lib/feat/cloudkit_sync/`) reads the same
keys (its `_cloudId` accepts both `cloud_id` and `cloudId`). **CloudKit's
`SyncOutboundService` delegates to this codec** — the two are byte-compatible by
construction, so the CloudKit tests double as codec tests.

> ⚠️ **Adding a synced column?** Update the serializer in `sync_record_codec.dart`
> *and* the matching `_upsert*` in `SyncReconciliationService`, or the new field
> silently won't sync or back up. This is in addition to the Drift migration
> work in [migrations](../standards/migrations.md).

## The file/ZIP backup

`lib/feat/backup/file_sync_transport.dart`. Archive layout:

```text
manifest.json   { appVersion, schemaVersion, exportedAt, recordTypes, counts }
records.json    [ <canonical record>, … ]   (backupRecordTypes only)
audio/<cloudId>__<filename>                  (one per local-file recording)
```

- **`buildArchive` / `readArchive` are the testable core**; `push` (share sheet)
  and `pull` (from in-memory source) are thin `SyncTransport` adapters.
- **Audio** is the one thing the record format doesn't carry (records hold only
  a recording `url`). The file transport bundles the bytes of every *local-file*
  recording (`file://` / `app-data:`) and, on import, materializes them with
  `copyIntoAudioStore` (`recording_file_store.dart`) and rewrites `url` to the
  new local path. External urls (https/spotify/music-catalog) pass through
  untouched. Re-import skips audio that's already present locally (no orphans).
- **Import is merge/dedupe**, reusing `SyncReconciliationService.applyFetched` —
  idempotent: re-importing the same ZIP is a no-op.
- **`schemaVersion` guard**: `readArchive` throws `BackupFormatException` if the
  archive's schema is newer than the running app.
- Imported rows are applied under `withSuppressedRowEvents`, so they do **not**
  auto-stage to CloudKit. Use **Settings → iCloud Sync → Sync now** (full push)
  to propagate a restored library to iCloud.

### Record-type scope

`backupRecordTypes` (in `file_sync_transport.dart`) is the file backup's scope.
It is set to `allSyncRecordTypes` — **the ZIP mirrors CloudKit exactly**,
`AppSetting` included — so every external data source (iCloud, file, future cloud
drives) carries the same data and behaves uniformly. `serializeAll` still takes a
`recordTypes` filter, so a transport *can* narrow its scope, but the default and
the intent is parity. When adding a transport, prefer `allSyncRecordTypes` unless
there's a concrete reason to diverge.

## UI

`lib/feat/backup/backup_providers.dart` exposes `backupProvider`
(`AsyncNotifier<BackupState>`); Import/Export tiles live in
`lib/feat/settings/settings_page.dart`. Import → file picker (`.zip`) → confirm →
merge, with a snackbar summary. Export → `FileSyncTransport.deliver`: a native
**Save** panel on desktop (the macOS share sheet has no "Save to Files") and the
**share sheet** on iOS/Android (whose "Save to Files" covers the same need). A
cancelled save panel resets to idle with no snackbar.

## Adding a new transport (e.g. Dropbox / Google Drive)

1. Implement `SyncTransport` in a new feature folder.
2. `push(records)` writes the canonical records (and, for a file/drive backend,
   the `audio/` blobs) to the backend; `pull()` reads them back into a
   `FetchedChanges`.
3. Reuse `serializeAll` for export and `applyFetched` for import — **do not**
   write a second serializer or a second dedupe path.
4. Decide the transport's record-type scope (mirror `backupRecordTypes` or pass
   `allSyncRecordTypes`).

## Deps & platform notes

- `archive` (pure-Dart ZIP) — no native code, safe under the SPM-only /
  no-CocoaPods constraint.
- `share_plus` for the export share sheet — **must resolve under Swift Package
  Manager** (no Podfile allowed). If a version pulls in CocoaPods, fall back to
  `file_picker`'s save-file API. (Tests run on the Dart VM and don't exercise the
  native share path, so green tests don't prove SPM resolution — check a real
  device build.)

## Tests

- `lib/feat/sync_core/sync_record_codec_test.dart` — record-type coverage,
  scope filtering, join parent cloud_ids, `recordsToFetchedChanges`.
- `lib/feat/backup/file_sync_transport_roundtrip_test.dart` — export → import
  into a fresh DB (incl. audio round-trip), idempotent re-import, malformed-bytes
  rejection. Fakes `PathProviderPlatform` for docs + temp dirs.
