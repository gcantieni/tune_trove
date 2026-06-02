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

Both optimizations originally tracked here have landed (details below), and as
of this revision **all follow-ups are complete** — see the closed checklist.

## ✅ Completed follow-ups

**Incremental staging (§1):**
- [x] **Periodic reconciliation sweep.** `SyncStager` now runs a low-frequency
  (30 min) silent `fullPush` sweep (`sweepInterval`), re-staging every row so a
  mutation a hook missed converges without waiting for a manual "Sync Now".
- [x] **Auto-push failures surface.** `SyncStager` forwards every background
  push's `SendResult` via an `onResult` callback to
  `SyncNotifier.reportBackgroundResult`, which flips the tile to `partial` on
  failure (clean results only refresh the timestamp — no noisy success snackbar).

**Partial-failure surfacing (§2):**
- [x] **Per-failure reasons shown.** `SyncState.failures` now carries the sample;
  the iCloud sync tile is tappable when records fail ("· tap for details") and
  opens a dialog listing the reasons.
- [x] **Retry policy for transient codes.** `CloudKitSyncBridge` classifies
  transient terminal errors (network/rate-limit/serviceUnavailable/zoneBusy) and
  re-stages them with a guarded, coalesced backoff resend
  (`scheduleBackoffResend`, honoring `retryAfterSeconds`); only truly permanent
  codes (quota/schema/permissions) are counted and reported.
- [x] **Dead `statusEvents` removed.** The unused `status` EventChannel path
  (`SyncStatusEvent`, `statusEvents`, `emitStatus`) was deleted from the Dart
  interface, the platform service, and the native bridge.

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

### Follow-ups — DONE

- **Periodic reconciliation sweep:** `SyncStager.sweepInterval` (30 min) runs a
  silent `_outbound.syncNow(fullPush: true)`, re-staging every row to self-heal
  any mutation a hook missed.
- **Auto-push status:** `SyncStager` reports each background `SendResult` to
  `SyncNotifier.reportBackgroundResult`, so a silent auto-push's failures now
  surface on the tile immediately instead of waiting for the next manual sync.

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

### Follow-ups — DONE

- **Per-failure reasons surfaced:** `SyncState.failures` carries the sample; the
  sync tile shows "· tap for details" and opens a dialog listing the reasons.
- **Retry policy for transient codes:** `CloudKitSyncBridge.isTransientFailure`
  re-stages network/rate-limit/serviceUnavailable/zoneBusy failures and schedules
  a guarded, coalesced backoff resend; permanent codes stay report-only.
- **`statusEvents` removed:** the unused status EventChannel path was deleted
  end-to-end (Dart interface, platform service, and native `emitStatus`).
