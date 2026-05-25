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

## 2. Surface partial / per-record sync failures

### Problem

`CKSyncEngine` reports per-record save failures via the
`.sentRecordZoneChanges` event, handled in `CloudKitSyncBridge.handleSentChanges`
— which currently only `print`s the `failedRecordSaves`. `sendChanges()` does
**not** throw for per-record failures, so `syncNow()` returns normally and
`SyncNotifier` reports `success` even if some records never saved. The UI lies
about a partial sync.

### Goal

Make `syncNow` honest: when some records fail to upload, surface that to the user
(e.g. "Synced — 3 items couldn't upload") rather than a flat success.

### Implementation sketch

1. In `CloudKitSyncBridge`, accumulate the outcome of a send (saved count, failed
   count, and a sample of failure reasons via the existing `describeError`) the
   same way `fetchChanges` accumulates results.
2. Return that summary from the `sendChanges` method-channel call (today it
   returns `nil`), mirroring how `fetchChanges` returns a map. Plumb it through
   `CloudKitSyncService.sendChanges` (`platform_cloudkit_sync_service.dart`).
3. `SyncOutboundService.syncNow()` captures the summary and returns it.
4. Extend `SyncState` with a `partial`/warning notion (e.g. a `failedCount` field
   or a `SyncPhase.partial`). In the settings tile, render it amber with the count,
   distinct from a hard `error`.

### Tradeoffs / open questions

- The repurposable `statusEvents` EventChannel (currently emitted by the bridge
  but no longer consumed since the notifier refactor) could carry richer
  progress/partial-failure events instead of overloading the method-channel
  return value. Pick one mechanism.
- Decide retry policy for the failed subset: the bridge already re-stages
  `serverRecordChanged` conflicts; other failure codes (`unknownItem`, quota,
  schema) need a product decision on whether/when to retry vs. report.
