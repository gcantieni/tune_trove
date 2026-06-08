// package imports
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

/// A sink/source for the canonical record format (see [sync_record_codec]).
///
/// Every way the library can leave or re-enter the device — CloudKit, a
/// file/ZIP backup, a future Dropbox or Google Drive folder — is just a
/// [SyncTransport]. Callers serialize the database with `serializeAll` and
/// [push] the records; they [pull] a [FetchedChanges] and hand it to
/// `SyncReconciliationService.applyFetched`, which dedupes and merges the same
/// way regardless of where the records came from.
///
/// Audio files are *not* part of the canonical record format (records carry
/// only a recording `url`). A file-based transport bundles the referenced local
/// audio alongside the records as an implementation detail of [push]/[pull];
/// CloudKit carries none.
abstract class SyncTransport {
  /// Stable identifier, e.g. `cloudkit`, `file`, `dropbox`.
  String get id;

  /// Reads the backend's current state as a change set ready for
  /// reconciliation. For a backup file this parses the archive; for CloudKit it
  /// fetches remote changes.
  Future<FetchedChanges> pull();

  /// Writes [records] to the backend. For a backup file this produces the
  /// archive; for CloudKit it stages and sends.
  Future<void> push(List<Map<String, dynamic>> records);
}

/// Adapts the existing [CloudKitSyncService] to the [SyncTransport] interface.
///
/// This does not replace the established CloudKit sync cycle in
/// `SyncOutboundService` (which interleaves fetch→reconcile→stage→send for
/// dedupe); it exposes the same backend through the shared interface so the
/// backup feature and CloudKit are interchangeable from a caller's view.
class CloudKitSyncTransport implements SyncTransport {
  final CloudKitSyncService _service;

  CloudKitSyncTransport(this._service);

  @override
  String get id => 'cloudkit';

  @override
  Future<FetchedChanges> pull() async {
    await _service.initialize();
    return _service.fetchChanges();
  }

  @override
  Future<void> push(List<Map<String, dynamic>> records) async {
    await _service.initialize();
    if (records.isNotEmpty) await _service.stageRecords(records);
    await _service.sendChanges();
  }
}
