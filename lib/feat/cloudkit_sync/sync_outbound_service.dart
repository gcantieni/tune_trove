import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/feat/sync_core/sync_record_codec.dart';
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
      final records = await serializeAll(_db, recordTypes: allSyncRecordTypes);
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
        return t == null ? null : serializeTune(t);
      case 'Recording':
        final r = await _db.recordingDao.getByCloudId(cloudId);
        return r == null ? null : serializeRecording(r);
      case 'TuneSet':
        final s = await _db.setDao.getByCloudId(cloudId);
        return s == null ? null : serializeTuneSet(s);
      case 'TuneRecording':
        final tr = await _db.tuneRecordingDao.getByCloudId(cloudId);
        if (tr == null) return null;
        final tune = await _db.tuneDao.getTune(tr.tuneId);
        final rec = await _db.recordingDao.getRecording(tr.recordingId);
        if (tune?.cloudId == null || rec?.cloudId == null) return null;
        return serializeTuneRecording(
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
        return serializeSetTune(
          st,
          setCloudId: set!.cloudId!,
          tuneCloudId: tune!.cloudId!,
        );
      case 'SourceConfirmation':
        final c = await _db.sourceConfirmationDao.getByCloudId(cloudId);
        return c == null ? null : serializeSourceConfirmation(c);
      case 'SourceRanking':
        final r = await _db.sourceRankingsDao.getByCloudId(cloudId);
        return r == null ? null : serializeSourceRanking(r);
      case 'AppSetting':
        final s = await _db.appSettingsDao.getByCloudId(cloudId);
        return s == null ? null : serializeAppSetting(s);
    }
    return null;
  }
}
