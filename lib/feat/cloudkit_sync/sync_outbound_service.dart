import 'package:shared_preferences/shared_preferences.dart';
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
  final SharedPreferences _prefs;

  SyncOutboundService(this._db, this._sync, this._reconciliation, this._prefs);

  static const _backfillKey = 'sync_initial_push_done';

  /// Serializes sync cycles so concurrent triggers (launch, pull-to-refresh,
  /// manual button, push) can't overlap — overlapping `fetchChanges` calls would
  /// corrupt the bridge's per-fetch accumulators.
  Future<SendResult> _chain = Future.value(const SendResult());

  /// Runs one deterministic sync cycle: fetch remote -> reconcile locally ->
  /// stage -> send. Fetching and reconciling *before* staging is what lets a
  /// device with existing tunes adopt remote ids (dedupe) instead of uploading
  /// duplicates.
  ///
  /// Every local row is staged only on the first ever sync (backfill) or when
  /// [fullPush] is requested (the manual "Sync Now" button, as a safety net).
  /// Otherwise this just flushes whatever [SyncStager] staged incrementally at
  /// mutation time.
  Future<SendResult> syncNow({bool fullPush = false}) {
    final result = _chain.then(
      (_) => _runSync(fullPush: fullPush),
      onError: (_) => _runSync(fullPush: fullPush),
    );
    // Track completion without letting one failure break the chain.
    _chain = result.then((r) => r, onError: (_) => const SendResult());
    return result;
  }

  Future<SendResult> _runSync({required bool fullPush}) async {
    await _sync.initialize();
    final fetched = await _sync.fetchChanges();
    await _reconciliation.applyFetched(fetched);
    final backfilled = _prefs.getBool(_backfillKey) ?? false;
    if (fullPush || !backfilled) {
      final records = await _serializeAll();
      if (records.isNotEmpty) await _sync.stageRecords(records);
      await _prefs.setBool(_backfillKey, true);
    }
    return _sync.sendChanges();
  }

  /// Serializes a single local row (by cloud_id) for incremental staging.
  /// Returns null if the row no longer exists or a join's parents are missing.
  Future<Map<String, dynamic>?> serializeByCloudId(
    String recordType,
    String cloudId,
  ) async {
    switch (recordType) {
      case 'Tune':
        final t = await _db.tuneDao.getByCloudId(cloudId);
        return t == null ? null : _serializeTune(t);
      case 'Recording':
        final r = await _db.recordingDao.getByCloudId(cloudId);
        return r == null ? null : _serializeRecording(r);
      case 'TuneSet':
        final s = await _db.setDao.getByCloudId(cloudId);
        return s == null ? null : _serializeTuneSet(s);
      case 'TuneRecording':
        final tr = await _db.tuneRecordingDao.getByCloudId(cloudId);
        if (tr == null) return null;
        final tune = await _db.tuneDao.getTune(tr.tuneId);
        final rec = await _db.recordingDao.getRecording(tr.recordingId);
        if (tune?.cloudId == null || rec?.cloudId == null) return null;
        return _serializeTuneRecording(
          tr,
          tuneCloudId: tune!.cloudId!,
          recordingCloudId: rec!.cloudId!,
        );
      case 'SetTune':
        final st = await _db.setTuneDao.getByCloudId(cloudId);
        if (st == null) return null;
        final set = await _db.setDao.getSet(st.setId);
        final tune = await _db.tuneDao.getTune(st.tuneId);
        if (set?.cloudId == null || tune?.cloudId == null) return null;
        return _serializeSetTune(
          st,
          setCloudId: set!.cloudId!,
          tuneCloudId: tune!.cloudId!,
        );
      case 'SourceConfirmation':
        final c = await _db.sourceConfirmationDao.getByCloudId(cloudId);
        return c == null ? null : _serializeSourceConfirmation(c);
      case 'SourceRanking':
        final r = await _db.sourceRankingsDao.getByCloudId(cloudId);
        return r == null ? null : _serializeSourceRanking(r);
    }
    return null;
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

    for (final c in await _db.sourceConfirmationDao.getAll()) {
      if (c.cloudId == null) continue;
      records.add(_serializeSourceConfirmation(c));
    }

    for (final r in await _db.sourceRankingsDao.getAll()) {
      if (r.cloudId == null) continue;
      records.add(_serializeSourceRanking(r));
    }

    return records;
  }

  // ---------------------------------------------------------------------------
  // Per-type serializers
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _serializeTune(Tune t) => {
    'recordType': 'Tune',
    'cloudId': t.cloudId,
    'name': t.name,
    if (t.abc != null) 'abc': t.abc,
    if (t.tsId != null) 'ts_id': t.tsId,
    if (t.from != null) 'from': t.from,
    if (t.status != null) 'status': t.status!.name,
    if (t.key != null) 'key': t.key,
    if (t.type != null) 'type': t.type!.name,
    if (t.genre != null) 'genre': t.genre,
    'created_at': t.createdAt.millisecondsSinceEpoch,
    if (t.modifiedAt != null)
      'modified_at': t.modifiedAt!.millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _serializeRecording(Recording r) => {
    'recordType': 'Recording',
    'cloudId': r.cloudId,
    'name': r.name,
    'url': r.url,
    if (r.performers != null) 'performers': r.performers,
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
    'cloudId': tr.cloudId,
    'tune_cloud_id': tuneCloudId,
    'recording_cloud_id': recordingCloudId,
    // start_time / end_time are audio-position seconds (double), not dates.
    if (tr.startTime != null) 'start_time': tr.startTime,
    if (tr.endTime != null) 'end_time': tr.endTime,
    if (tr.performers != null) 'performers': tr.performers,
    if (tr.performedKey != null) 'performed_key': tr.performedKey,
  };

  static Map<String, dynamic> _serializeTuneSet(TuneSet s) => {
    'recordType': 'TuneSet',
    'cloudId': s.cloudId,
    'name': s.name,
    'position': s.position,
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
    'cloudId': st.cloudId,
    'set_cloud_id': setCloudId,
    'tune_cloud_id': tuneCloudId,
    'position': st.position,
    if (st.key != null) 'key': st.key,
  };

  static Map<String, dynamic> _serializeSourceConfirmation(
    SourceConfirmation c,
  ) => {
    'recordType': 'SourceConfirmation',
    'cloudId': c.cloudId,
    'source_id': c.sourceId,
    if (c.license != null) 'license': c.license,
    'created_at': c.createdAt.millisecondsSinceEpoch,
    if (c.modifiedAt != null)
      'modified_at': c.modifiedAt!.millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _serializeSourceRanking(SourceRanking r) => {
    'recordType': 'SourceRanking',
    'cloudId': r.cloudId,
    'source_id': r.sourceId,
    'rank': r.rank,
    if (r.modifiedAt != null)
      'modified_at': r.modifiedAt!.millisecondsSinceEpoch,
  };
}
