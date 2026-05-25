# Roadmap: CloudKit Sync Optimizations

## Background

CloudKit sync runs on Apple's `CKSyncEngine` (see `ios/Runner/CloudKitSyncBridge.swift`)
with `automaticallySync = false`, driven manually from
`SyncOutboundService.syncNow()` (`lib/feat/cloudkit_sync/sync_outbound_service.dart`):

```
initialize → fetchChanges → reconcile (SyncReconciliationService) → stage → sendChanges
```

`SyncNotifier`/`SyncState` (`lib/feat/cloudkit_sync/sync_notifier.dart`) surfaces a
single status to the settings tile (`idle | syncing | success | error | unavailable`).

Both optimizations originally tracked here are now implemented (details below),
each with a short list of remaining follow-ups.

---

## 1. Incremental ("dirty row") staging — IMPLEMENTED

Mutations now sync automatically and incrementally instead of via a full
re-push.

- **Capture:** `AppDatabase.onRowChanged` (`lib/model/database.dart`) is a
  sync-agnostic hook every DAO `insert/update/delete` calls via
  `notifyRowChanged(recordType, cloudId, deleted:)`. The sync layer registers the
  hook (DB never imports the sync feature → no dependency cycle). Deletes look up
  the `cloud_id` before deleting; compound methods (`createTuneAndLink`,
  `createRecordingAndLink`, `reorderTune`, `_bumpTuneModified`) emit for every
  affected row.
- **Suppression:** reconciliation wraps its writes in
  `AppDatabase.withSuppressedRowEvents`, which uses a **`Zone`** (not a flag) so a
  user edit that interleaves at an `await` is still captured — only
  reconciliation's own async chain is suppressed.
- **Stage + push:** `SyncStager` (`sync_stager.dart`) serializes the changed row
  (`SyncOutboundService.serializeByCloudId`) → `stageRecords` / `stageDeletions`,
  then debounces a quiet `sendChanges` (3s). Started for the app's lifetime via
  `syncStagerProvider` watched in `main.dart`.
- **Durability:** `CKSyncEngine` persists *which* records are pending; the bridge
  now also persists the field data (`pendingRecordMaps` → `ck_pending_maps.json`),
  so an incrementally-staged change survives an app restart.
- **Backfill + safety net:** `syncNow()` stages all rows only on the first ever
  sync (`sync_initial_push_done` pref) or when `fullPush: true`. The manual "Sync
  Now" button passes `fullPush: true`, so it doubles as a force-full-resync /
  recovery path for any row a hook might have missed.

### Remaining follow-ups

- No periodic reconciliation sweep yet; the manual full-push is the only recovery
  if a mutation path is ever added without an `onRowChanged` call.
- The debounced auto-push is silent (no `SyncNotifier` status); partial failures
  on an auto-push only surface on the next manual sync.

---

## 2. Surface partial / per-record sync failures — IMPLEMENTED

`sendChanges` now returns a `{saved, failedCount, failures}` summary.
`CloudKitSyncBridge.performSend` resets per-send accumulators and
`handleSentChanges` counts saved records and **terminal** failures only —
recoverable cases (`serverRecordChanged` conflicts, `zoneNotFound`) are re-staged
and not counted; `unknownItem` is treated as a benign delete-race. The summary
flows `CloudKitSyncService.sendChanges` → `SendResult` →
`SyncOutboundService.syncNow` → `SyncNotifier`, which sets `SyncPhase.partial`
(amber `sync_problem` row, "N items couldn't upload · synced …") when
`failedCount > 0`, distinct from a hard `error`.

### Remaining follow-ups

- The per-failure reasons are carried in `SendResult.failures` (sample of 5) but
  not yet shown anywhere — a details/expand affordance on the tile could surface
  them.
- Retry policy for terminal failure codes (quota, schema, etc.) is still
  report-only; only conflict/zone cases are auto-retried.
- The `statusEvents` EventChannel is emitted by the bridge but no longer consumed
  since the notifier refactor — either repurpose it for richer progress events or
  remove it.
