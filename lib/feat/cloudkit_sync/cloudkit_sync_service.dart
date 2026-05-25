class SyncStatusEvent {
  final String status; // 'idle' | 'syncing' | 'error'
  final String? message;
  SyncStatusEvent(this.status, {this.message});
}

class SyncUpsertEvent {
  final String recordType;
  final Map<String, dynamic> fields;
  SyncUpsertEvent(this.recordType, this.fields);
}

class SyncDeleteEvent {
  final String recordType;
  final String cloudId;
  SyncDeleteEvent(this.recordType, this.cloudId);
}

/// The result of pulling remote changes: records to upsert and records that
/// were deleted on another device.
class FetchedChanges {
  final List<SyncUpsertEvent> upserts;
  final List<SyncDeleteEvent> deletions;
  const FetchedChanges(this.upserts, this.deletions);

  bool get isEmpty => upserts.isEmpty && deletions.isEmpty;
}

/// Drives an explicit, deterministic CloudKit sync cycle backed by
/// `CKSyncEngine` on the native side. A full sync is:
/// `fetchChanges` -> reconcile -> `stageRecords` -> `sendChanges`.
abstract class CloudKitSyncService {
  /// Whether the user is signed in to iCloud and the account is usable.
  Future<bool> isAvailable();

  /// Lazily creates the native sync engine (rehydrating persisted state).
  Future<void> initialize();

  /// Pulls remote changes and returns them. Reconciliation is the caller's
  /// responsibility and must complete before staging local records.
  Future<FetchedChanges> fetchChanges();

  /// Queues local records for upload on the next [sendChanges].
  Future<void> stageRecords(List<Map<String, dynamic>> records);

  /// Queues record deletions (by cloudId) for the next [sendChanges].
  Future<void> stageDeletions(List<Map<String, dynamic>> deletions);

  /// Flushes all staged changes to CloudKit.
  Future<void> sendChanges();

  /// Status updates emitted by the engine ('idle' | 'syncing' | 'error').
  Stream<SyncStatusEvent> get statusEvents;

  void dispose();
}
