import 'dart:async';

import 'package:drift/drift.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';

class SyncReconciliationService {
  final AppDatabase _db;
  final CloudKitSyncService _sync;
  StreamSubscription<SyncEvent>? _sub;

  SyncReconciliationService(this._db, this._sync);

  void start() {
    _sub = _sync.syncEvents.listen(_handleEvent);
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleEvent(SyncEvent event) {
    switch (event) {
      case SyncUpsertEvent(:final recordType, :final fields):
        _upsert(recordType, fields).ignore();
      case SyncDeleteEvent(:final recordType, :final cloudId):
        _delete(recordType, cloudId).ignore();
      case SyncStatusEvent():
        break;
    }
  }

  Future<void> _upsert(String recordType, Map<String, dynamic> fields) async {
    switch (recordType) {
      case 'Tune':
        await _upsertTune(fields);
      case 'Recording':
        await _upsertRecording(fields);
      case 'TuneRecording':
        await _upsertTuneRecording(fields);
      case 'TuneSet':
        await _upsertTuneSet(fields);
      case 'SetTune':
        await _upsertSetTune(fields);
    }
  }

  Future<void> _delete(String recordType, String cloudId) async {
    switch (recordType) {
      case 'Tune':
        final row = await _db.tuneDao.getByCloudId(cloudId);
        if (row != null) await _db.tuneDao.deleteTune(row.id);
      case 'Recording':
        final row = await _db.recordingDao.getByCloudId(cloudId);
        if (row != null) await _db.recordingDao.deleteRecording(row.id);
      case 'TuneRecording':
        final row = await _db.tuneRecordingDao.getByCloudId(cloudId);
        if (row != null) {
          await _db.tuneRecordingDao.unlinkTuneFromRecording(
            row.tuneId,
            row.recordingId,
          );
        }
      case 'TuneSet':
        final row = await _db.setDao.getByCloudId(cloudId);
        if (row != null) await _db.setDao.deleteSet(row.id);
      case 'SetTune':
        final row = await _db.setTuneDao.getByCloudId(cloudId);
        if (row != null) await _db.setTuneDao.removeTuneFromSet(row.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Per-type upsert helpers
  // ---------------------------------------------------------------------------

  Future<void> _upsertTune(Map<String, dynamic> f) async {
    final cloudId = f['cloud_id'] as String? ?? f['cloudId'] as String?;
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);
    final existing = await _db.tuneDao.getByCloudId(cloudId);
    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      if (incoming != null && !incoming.isAfter(localModified)) return;
      await _db.tuneDao.updateTune(
        TunesCompanion(
          id: Value(existing.id),
          name: Value(_str(f, 'name') ?? existing.name),
          abc: Value(_str(f, 'abc')),
          tsId: Value(_int(f, 'ts_id')),
          from: Value(_str(f, 'from')),
          status: Value(
            _str(f, 'status') != null
                ? TuneStatus.values.byName(_str(f, 'status')!)
                : null,
          ),
          key: Value(_str(f, 'key')),
          type: Value(
            _str(f, 'type') != null
                ? TuneType.values.byName(_str(f, 'type')!)
                : null,
          ),
          genre: Value(_str(f, 'genre')),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    } else {
      await _db.tuneDao.insertTune(
        TunesCompanion.insert(
          name: _str(f, 'name') ?? '',
          abc: Value(_str(f, 'abc')),
          tsId: Value(_int(f, 'ts_id')),
          from: Value(_str(f, 'from')),
          status: Value(
            _str(f, 'status') != null
                ? TuneStatus.values.byName(_str(f, 'status')!)
                : null,
          ),
          key: Value(_str(f, 'key')),
          type: Value(
            _str(f, 'type') != null
                ? TuneType.values.byName(_str(f, 'type')!)
                : null,
          ),
          genre: Value(_str(f, 'genre')),
          createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    }
  }

  Future<void> _upsertRecording(Map<String, dynamic> f) async {
    final cloudId = f['cloud_id'] as String? ?? f['cloudId'] as String?;
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);
    final existing = await _db.recordingDao.getByCloudId(cloudId);
    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      if (incoming != null && !incoming.isAfter(localModified)) return;
      await _db.recordingDao.updateRecording(
        existing.copyWith(
          name: _str(f, 'name') ?? existing.name,
          url: _str(f, 'url') ?? existing.url,
          performers: Value(_str(f, 'performers')),
          modifiedAt: Value(_dateOf(f['modified_at'])),
        ),
      );
    } else {
      await _db.recordingDao.insertRecording(
        RecordingsCompanion.insert(
          name: _str(f, 'name') ?? '',
          url: _str(f, 'url') ?? '',
          performers: Value(_str(f, 'performers')),
          createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    }
  }

  Future<void> _upsertTuneRecording(Map<String, dynamic> f) async {
    final cloudId = f['cloud_id'] as String? ?? f['cloudId'] as String?;
    final tuneCloudId = f['tune_cloud_id'] as String? ?? f['tuneCloudId'] as String?;
    final recCloudId =
        f['recording_cloud_id'] as String? ?? f['recordingCloudId'] as String?;
    if (cloudId == null || tuneCloudId == null || recCloudId == null) return;

    final tune = await _db.tuneDao.getByCloudId(tuneCloudId);
    final recording = await _db.recordingDao.getByCloudId(recCloudId);
    if (tune == null || recording == null) return;

    final existing = await _db.tuneRecordingDao.getByCloudId(cloudId);
    if (existing != null) {
      await _db.tuneRecordingDao.updateLink(
        existing.copyWith(
          startTime: Value(_double(f, 'start_time')),
          endTime: Value(_double(f, 'end_time')),
          performers: Value(_str(f, 'performers')),
          performedKey: Value(_str(f, 'performed_key')),
        ),
      );
    } else {
      await _db.tuneRecordingDao.linkTuneToRecording(
        tune.id,
        recording.id,
        startTime: _double(f, 'start_time'),
        endTime: _double(f, 'end_time'),
        performedKey: _str(f, 'performed_key'),
      );
    }
  }

  Future<void> _upsertTuneSet(Map<String, dynamic> f) async {
    final cloudId = f['cloud_id'] as String? ?? f['cloudId'] as String?;
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);
    final existing = await _db.setDao.getByCloudId(cloudId);
    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      if (incoming != null && !incoming.isAfter(localModified)) return;
      await _db.setDao.updateSet(
        TuneSetsCompanion(
          id: Value(existing.id),
          name: Value(_str(f, 'name') ?? existing.name),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    } else {
      await _db.setDao.insertSet(
        TuneSetsCompanion.insert(
          name: _str(f, 'name') ?? '',
          createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    }
  }

  Future<void> _upsertSetTune(Map<String, dynamic> f) async {
    final cloudId = f['cloud_id'] as String? ?? f['cloudId'] as String?;
    final setCloudId = f['set_cloud_id'] as String? ?? f['setCloudId'] as String?;
    final tuneCloudId = f['tune_cloud_id'] as String? ?? f['tuneCloudId'] as String?;
    if (cloudId == null || setCloudId == null || tuneCloudId == null) return;

    final tuneSet = await _db.setDao.getByCloudId(setCloudId);
    final tune = await _db.tuneDao.getByCloudId(tuneCloudId);
    if (tuneSet == null || tune == null) return;

    final existing = await _db.setTuneDao.getByCloudId(cloudId);
    if (existing != null) {
      await _db.setTuneDao.updateKey(existing.id, _str(f, 'key'));
    } else {
      await _db.setTuneDao.addTuneToSet(tuneSet.id, tune.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Field extraction helpers
  // ---------------------------------------------------------------------------

  String? _str(Map<String, dynamic> f, String key) {
    final v = f[key];
    return v is String ? v : null;
  }

  int? _int(Map<String, dynamic> f, String key) {
    final v = f[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return null;
  }

  double? _double(Map<String, dynamic> f, String key) {
    final v = f[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return null;
  }

  DateTime? _dateOf(dynamic v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return null;
  }
}
