sealed class SyncEvent {}

class SyncStatusEvent extends SyncEvent {
  final String status; // 'idle' | 'syncing' | 'error'
  final String? message;
  SyncStatusEvent(this.status, {this.message});
}

class SyncUpsertEvent extends SyncEvent {
  final String recordType;
  final Map<String, dynamic> fields;
  SyncUpsertEvent(this.recordType, this.fields);
}

class SyncDeleteEvent extends SyncEvent {
  final String recordType;
  final String cloudId;
  SyncDeleteEvent(this.recordType, this.cloudId);
}

abstract class CloudKitSyncService {
  Future<bool> isAvailable();
  Future<void> startSync();
  Future<void> pushChanges(List<Map<String, dynamic>> records);
  Future<void> subscribeToChanges();
  Stream<SyncEvent> get syncEvents;
  void dispose();
}
