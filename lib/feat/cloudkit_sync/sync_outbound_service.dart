import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/model/database.dart';

/// Coordinates a full sync cycle and serializes the local Drift database into
/// CloudKit records.
///
/// The record format mirrors what [SyncReconciliationService] expects on
/// the inbound side: snake_case field keys, timestamps as ms-since-epoch
/// integers, enum values as their string name.
class SyncOutboundService {
  final AppDatabase _db;
  final CloudKitSyncService _sync;
  final SyncReconciliationService _reconciliation;

  SyncOutboundService(this._db, this._sync, this._reconciliation);

  /// Runs one deterministic sync cycle: fetch remote -> reconcile locally ->
  /// stage local records -> send. Fetching and reconciling *before* staging is
  /// what lets a device with existing tunes adopt remote ids (dedupe) instead
  /// of uploading duplicates.
  Future<void> syncNow() async {
    await _sync.initialize();
    final fetched = await _sync.fetchChanges();
    await _reconciliation.applyFetched(fetched);
    final records = await _serializeAll();
    if (records.isNotEmpty) await _sync.stageRecords(records);
    await _sync.sendChanges();
  }

  /// Serializes every record in the local database into CloudKit record maps.
  ///
  /// Join-table records (TuneRecording, SetTune) include the cloud_ids of
  /// their parent rows so the receiving device can resolve foreign keys.
  /// Rows missing a cloud_id are skipped (should not happen after the v9
  /// migration, but is handled defensively).
  Future<List<Map<String, dynamic>>> _serializeAll() async {
    final records = <Map<String, dynamic>>[];

    // Read all five tables up front to build id→cloudId maps for O(1) lookups
    // when serializing join tables.
    final tunes = await _db.tuneDao.getAll();
    final recs = await _db.recordingDao.getAll();
    final sets = await _db.setDao.getAll();
    final tuneById = {for (final t in tunes) t.id: t};
    final recById = {for (final r in recs) r.id: r};
    final setById = {for (final s in sets) s.id: s};

    for (final t in tunes) {
      if (t.cloudId == null) continue;
      records.add(_serializeTune(t));
    }

    for (final r in recs) {
      if (r.cloudId == null) continue;
      records.add(_serializeRecording(r));
    }

    final tuneRecordings = await _db.tuneRecordingDao.getAll();
    for (final tr in tuneRecordings) {
      if (tr.cloudId == null) continue;
      final tune = tuneById[tr.tuneId];
      final rec = recById[tr.recordingId];
      if (tune?.cloudId == null || rec?.cloudId == null) continue;
      records.add(
        _serializeTuneRecording(
          tr,
          tuneCloudId: tune!.cloudId!,
          recordingCloudId: rec!.cloudId!,
        ),
      );
    }

    for (final s in sets) {
      if (s.cloudId == null) continue;
      records.add(_serializeTuneSet(s));
    }

    final setTunes = await _db.setTuneDao.getAll();
    for (final st in setTunes) {
      if (st.cloudId == null) continue;
      final tuneSet = setById[st.setId];
      final tune = tuneById[st.tuneId];
      if (tuneSet?.cloudId == null || tune?.cloudId == null) continue;
      records.add(
        _serializeSetTune(
          st,
          setCloudId: tuneSet!.cloudId!,
          tuneCloudId: tune!.cloudId!,
        ),
      );
    }

    return records;
  }

  // ---------------------------------------------------------------------------
  // Per-type serializers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _serializeTune(Tune t) => {
    'recordType': 'Tune',
    'cloudId': t.cloudId!,
    'name': t.name,
    if (t.abc != null) 'abc': t.abc!,
    if (t.tsId != null) 'ts_id': t.tsId!,
    if (t.from != null) 'from': t.from!,
    if (t.status != null) 'status': t.status!.name,
    if (t.key != null) 'key': t.key!,
    if (t.type != null) 'type': t.type!.name,
    if (t.genre != null) 'genre': t.genre!,
    'created_at': t.createdAt.millisecondsSinceEpoch,
    if (t.modifiedAt != null)
      'modified_at': t.modifiedAt!.millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _serializeRecording(Recording r) => {
    'recordType': 'Recording',
    'cloudId': r.cloudId!,
    'name': r.name,
    'url': r.url,
    if (r.performers != null) 'performers': r.performers!,
    'created_at': r.createdAt.millisecondsSinceEpoch,
    if (r.modifiedAt != null)
      'modified_at': r.modifiedAt!.millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _serializeTuneRecording(
    TuneRecordingData tr, {
    required String tuneCloudId,
    required String recordingCloudId,
  }) => {
    'recordType': 'TuneRecording',
    'cloudId': tr.cloudId!,
    'tune_cloud_id': tuneCloudId,
    'recording_cloud_id': recordingCloudId,
    // start_time / end_time are audio-position seconds (double), not dates.
    if (tr.startTime != null) 'start_time': tr.startTime!,
    if (tr.endTime != null) 'end_time': tr.endTime!,
    if (tr.performers != null) 'performers': tr.performers!,
    if (tr.performedKey != null) 'performed_key': tr.performedKey!,
  };

  static Map<String, dynamic> _serializeTuneSet(TuneSet s) => {
    'recordType': 'TuneSet',
    'cloudId': s.cloudId!,
    'name': s.name,
    'created_at': s.createdAt.millisecondsSinceEpoch,
    if (s.modifiedAt != null)
      'modified_at': s.modifiedAt!.millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _serializeSetTune(
    SetTuneData st, {
    required String setCloudId,
    required String tuneCloudId,
  }) => {
    'recordType': 'SetTune',
    'cloudId': st.cloudId!,
    'set_cloud_id': setCloudId,
    'tune_cloud_id': tuneCloudId,
    'position': st.position,
    if (st.key != null) 'key': st.key!,
  };
}
