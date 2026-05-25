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

Two known gaps are deferred below. The first is a performance optimization; the
second closes the last correctness gap in *surfacing* status to the user.

---

## 1. Incremental ("dirty row") staging

### Problem

`SyncOutboundService._serializeAll()` serializes **every** local row on **every**
sync and hands the whole set to `stageRecords`. It is correct (upserts are
idempotent by `cloud_id`), but it is O(N): each already-synced record is
re-uploaded, and any record CloudKit considers unchanged still costs a
`serverRecordChanged` round-trip before the bridge's conflict path rebases it.
For a large tune library this makes every manual sync needlessly slow and chatty.

### Goal

Only upload rows that actually changed (created / edited / deleted) since the
last successful push, while keeping the full-push path as a fallback/first-sync
bootstrap.

### Proposed approach

Lean into what `CKSyncEngine` already does: it **persists pending record-zone
changes in its own state**. Instead of re-staging everything each sync, stage a
row the moment it is mutated, and let the engine carry the pending set (even
across app launches) until the next `sendChanges`.

### Implementation sketch

1. Add a thin "stage this row" hook invoked from DAO mutations
   (`insert*/update*/delete*` in `tune_dao.dart`, `recording_dao.dart`,
   `set_dao.dart`, `tune_recording_dao.dart`, `set_tune_dao.dart`). It serializes
   the single affected row (reuse the per-type serializers, refactored to take one
   row) and calls `CloudKitSyncService.stageRecords([record])` /
   `stageDeletions([...])`.
2. `syncNow()` becomes `fetch → reconcile → sendChanges` — no full serialize pass.
3. Keep `_serializeAll()` for two cases: (a) a one-time backfill the first time a
   device ever syncs (rows that predate the hook), gated by a persisted
   "didInitialPush" flag; (b) an explicit "force full re-sync" affordance.
4. Deletes must be staged too (the current full-push approach silently omits
   them) — `stageDeletions` already exists on the bridge but nothing calls it yet.

### Tradeoffs / open questions

- Wiring hooks into every DAO mutation is the bulk of the work and easy to miss a
  call site; a missed write means a silently un-synced row. Consider funneling all
  writes through a single choke point, or a periodic reconciliation sweep as a
  safety net.
- Riverpod wiring: DAOs don't currently depend on the sync layer. Avoid a
  dependency cycle (sync depends on DB). Likely route the staging through an
  app-level listener rather than the DAO directly.
- Decide how `cloud_id` assignment-on-insert interacts with staging order.

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
