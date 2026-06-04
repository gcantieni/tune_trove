import 'package:drift/drift.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';

/// Applies remote CloudKit changes into the local Drift database.
///
/// Inbound records are resolved by `cloud_id` first. When no row carries that
/// id, a row created independently on this device is matched by its natural key
/// (ts_id/name for tunes, url for recordings, name for sets) and *adopts* the
/// remote `cloud_id` instead of producing a duplicate — this is what keeps a
/// device that already had tunes from doubling its library on first sync.
class SyncReconciliationService {
  final AppDatabase _db;

  SyncReconciliationService(this._db);

  /// Applies a pulled change set. Base entities are reconciled before join
  /// tables so foreign keys resolve; deletions are applied join-first.
  ///
  /// Wrapped so these writes don't emit row-change events — otherwise every
  /// pulled record would be immediately re-staged for push.
  Future<void> applyFetched(FetchedChanges changes) {
    return _db.withSuppressedRowEvents(() async {
      for (final u in changes.upserts) {
        if (_isBaseType(u.recordType)) await _upsert(u.recordType, u.fields);
      }
      for (final u in changes.upserts) {
        if (!_isBaseType(u.recordType)) await _upsert(u.recordType, u.fields);
      }
      for (final d in changes.deletions) {
        if (!_isBaseType(d.recordType)) await _delete(d.recordType, d.cloudId);
      }
      for (final d in changes.deletions) {
        if (_isBaseType(d.recordType)) await _delete(d.recordType, d.cloudId);
      }
    });
  }

  bool _isBaseType(String t) =>
      t == 'Tune' ||
      t == 'Recording' ||
      t == 'TuneSet' ||
      t == 'SourceConfirmation' ||
      t == 'SourceRanking' ||
      t == 'AppSetting';

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
      case 'SourceConfirmation':
        await _upsertSourceConfirmation(fields);
      case 'SourceRanking':
        await _upsertSourceRanking(fields);
      case 'AppSetting':
        await _upsertAppSetting(fields);
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
      case 'SourceConfirmation':
        await _db.sourceConfirmationDao.deleteByCloudId(cloudId);
      case 'SourceRanking':
        await _db.sourceRankingsDao.deleteByCloudId(cloudId);
      case 'AppSetting':
        await _db.appSettingsDao.deleteByCloudId(cloudId);
    }
  }

  // ---------------------------------------------------------------------------
  // Per-type upsert helpers
  // ---------------------------------------------------------------------------

  Future<void> _upsertTune(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);

    var existing = await _db.tuneDao.getByCloudId(cloudId);
    if (existing == null) {
      // Dedupe against an independently-created row.
      final tsId = _int(f, 'ts_id');
      if (tsId != null) {
        existing = await _db.tuneDao.getByTsId(tsId);
      } else {
        final name = _str(f, 'name');
        if (name != null) existing = await _db.tuneDao.getByName(name);
      }
    }

    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      final remoteNewer = incoming != null && incoming.isAfter(localModified);
      if (existing.cloudId == cloudId && !remoteNewer) return;
      if (remoteNewer) {
        await _db.tuneDao.updateTune(
          TunesCompanion(
            id: Value(existing.id),
            name: Value(_str(f, 'name') ?? existing.name),
            abc: Value(_str(f, 'abc')),
            tsId: Value(_int(f, 'ts_id')),
            from: Value(_str(f, 'from')),
            source: Value(_str(f, 'source')),
            composer: Value(_str(f, 'composer')),
            status: Value(_tuneStatus(f)),
            key: Value(_str(f, 'key')),
            type: Value(_tuneType(f)),
            genre: Value(_str(f, 'genre')),
            modifiedAt: Value(_dateOf(f['modified_at'])),
            cloudId: Value(cloudId),
          ),
        );
      } else {
        // Local is newer (or no remote timestamp): keep local fields, adopt id.
        await _db.tuneDao.updateTune(
          TunesCompanion(id: Value(existing.id), cloudId: Value(cloudId)),
        );
      }
    } else {
      await _db.tuneDao.insertTune(
        TunesCompanion.insert(
          name: _str(f, 'name') ?? '',
          abc: Value(_str(f, 'abc')),
          tsId: Value(_int(f, 'ts_id')),
          from: Value(_str(f, 'from')),
          source: Value(_str(f, 'source')),
          composer: Value(_str(f, 'composer')),
          status: Value(_tuneStatus(f)),
          key: Value(_str(f, 'key')),
          type: Value(_tuneType(f)),
          genre: Value(_str(f, 'genre')),
          createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
        ),
      );
    }
  }

  Future<void> _upsertRecording(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);

    var existing = await _db.recordingDao.getByCloudId(cloudId);
    if (existing == null) {
      final url = _str(f, 'url');
      if (url != null && url.isNotEmpty) {
        existing = await _db.recordingDao.getByUrl(url);
      }
    }

    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      final remoteNewer = incoming != null && incoming.isAfter(localModified);
      if (existing.cloudId == cloudId && !remoteNewer) return;
      if (remoteNewer) {
        await _db.recordingDao.updateRecording(
          existing.copyWith(
            name: _str(f, 'name') ?? existing.name,
            url: _str(f, 'url') ?? existing.url,
            performers: Value(_str(f, 'performers')),
            modifiedAt: Value(_dateOf(f['modified_at'])),
            cloudId: Value(cloudId),
          ),
        );
      } else {
        await _db.recordingDao.updateRecording(
          existing.copyWith(cloudId: Value(cloudId)),
        );
      }
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

  Future<void> _upsertTuneSet(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    if (cloudId == null) return;
    final incoming = _dateOf(f['modified_at']) ?? _dateOf(f['created_at']);

    var existing = await _db.setDao.getByCloudId(cloudId);
    if (existing == null) {
      final name = _str(f, 'name');
      if (name != null) existing = await _db.setDao.getByName(name);
    }

    if (existing != null) {
      final localModified = existing.modifiedAt ?? existing.createdAt;
      final remoteNewer = incoming != null && incoming.isAfter(localModified);
      if (existing.cloudId == cloudId && !remoteNewer) return;
      if (remoteNewer) {
        final position = _int(f, 'position');
        await _db.setDao.updateSet(
          TuneSetsCompanion(
            id: Value(existing.id),
            name: Value(_str(f, 'name') ?? existing.name),
            modifiedAt: Value(_dateOf(f['modified_at'])),
            cloudId: Value(cloudId),
            position: position != null ? Value(position) : const Value.absent(),
          ),
        );
      } else {
        await _db.setDao.updateSet(
          TuneSetsCompanion(id: Value(existing.id), cloudId: Value(cloudId)),
        );
      }
    } else {
      final position = _int(f, 'position');
      await _db.setDao.insertSet(
        TuneSetsCompanion.insert(
          name: _str(f, 'name') ?? '',
          createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
          modifiedAt: Value(_dateOf(f['modified_at'])),
          cloudId: Value(cloudId),
          position: position != null ? Value(position) : const Value.absent(),
        ),
      );
    }
  }

  Future<void> _upsertTuneRecording(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    final tuneCloudId = _str(f, 'tune_cloud_id') ?? _str(f, 'tuneCloudId');
    final recCloudId =
        _str(f, 'recording_cloud_id') ?? _str(f, 'recordingCloudId');
    if (cloudId == null || tuneCloudId == null || recCloudId == null) return;

    final tune = await _db.tuneDao.getByCloudId(tuneCloudId);
    final recording = await _db.recordingDao.getByCloudId(recCloudId);
    if (tune == null || recording == null) return;

    final existing =
        await _db.tuneRecordingDao.getByCloudId(cloudId) ??
        await _db.tuneRecordingDao.getByTuneAndRecording(tune.id, recording.id);
    if (existing != null) {
      await _db.tuneRecordingDao.updateLink(
        existing.copyWith(
          startTime: Value(_double(f, 'start_time')),
          endTime: Value(_double(f, 'end_time')),
          performers: Value(_str(f, 'performers')),
          performedKey: Value(_str(f, 'performed_key')),
          cloudId: Value(cloudId),
        ),
      );
    } else {
      await _db.tuneRecordingDao.linkTuneToRecording(
        tune.id,
        recording.id,
        startTime: _double(f, 'start_time'),
        endTime: _double(f, 'end_time'),
        performedKey: _str(f, 'performed_key'),
        cloudId: cloudId,
      );
    }
  }

  Future<void> _upsertSetTune(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    final setCloudId = _str(f, 'set_cloud_id') ?? _str(f, 'setCloudId');
    final tuneCloudId = _str(f, 'tune_cloud_id') ?? _str(f, 'tuneCloudId');
    if (cloudId == null || setCloudId == null || tuneCloudId == null) return;

    final tuneSet = await _db.setDao.getByCloudId(setCloudId);
    final tune = await _db.tuneDao.getByCloudId(tuneCloudId);
    if (tuneSet == null || tune == null) return;

    final existing =
        await _db.setTuneDao.getByCloudId(cloudId) ??
        await _db.setTuneDao.getBySetAndTune(tuneSet.id, tune.id);
    if (existing != null) {
      if (existing.cloudId != cloudId) {
        await _db.setTuneDao.adoptCloudId(existing.id, cloudId);
      }
      await _db.setTuneDao.updateKey(existing.id, _str(f, 'key'));
    } else {
      await _db.setTuneDao.addTuneToSet(
        tuneSet.id,
        tune.id,
        cloudId: cloudId,
        position: _int(f, 'position'),
        key: _str(f, 'key'),
      );
    }
  }

  Future<void> _upsertSourceConfirmation(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    final sourceId = _str(f, 'source_id') ?? _str(f, 'sourceId');
    if (cloudId == null || sourceId == null) return;

    var existing = await _db.sourceConfirmationDao.getByCloudId(cloudId);
    existing ??= await _db.sourceConfirmationDao.getBySourceId(sourceId);

    if (existing != null) {
      // Already confirmed locally; just adopt the remote cloud_id/license.
      if (existing.cloudId != cloudId ||
          existing.license != _str(f, 'license')) {
        await _db.sourceConfirmationDao.adoptRemote(
          existing.id,
          cloudId: cloudId,
          license: _str(f, 'license'),
          modifiedAt: _dateOf(f['modified_at']),
        );
      }
    } else {
      await _db.sourceConfirmationDao.insertFromRemote(
        sourceId: sourceId,
        cloudId: cloudId,
        license: _str(f, 'license'),
        createdAt: _dateOf(f['created_at']) ?? DateTime.now(),
        modifiedAt: _dateOf(f['modified_at']),
      );
    }
  }

  Future<void> _upsertSourceRanking(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    final sourceId = _str(f, 'source_id') ?? _str(f, 'sourceId');
    final rank = _int(f, 'rank');
    if (cloudId == null || sourceId == null || rank == null) return;

    await _db.sourceRankingsDao.upsertFromRemote(
      sourceId: sourceId,
      cloudId: cloudId,
      rank: rank,
      modifiedAt: _dateOf(f['modified_at']),
    );
  }

  Future<void> _upsertAppSetting(Map<String, dynamic> f) async {
    final cloudId = _cloudId(f);
    final key = _str(f, 'key');
    final value = _str(f, 'value');
    if (cloudId == null || key == null || value == null) return;

    await _db.appSettingsDao.upsertFromRemote(
      key: key,
      cloudId: cloudId,
      value: value,
      modifiedAt: _dateOf(f['modified_at']),
    );
  }

  // ---------------------------------------------------------------------------
  // Field extraction helpers
  // ---------------------------------------------------------------------------

  String? _cloudId(Map<String, dynamic> f) =>
      f['cloud_id'] as String? ?? f['cloudId'] as String?;

  TuneStatus? _tuneStatus(Map<String, dynamic> f) {
    final s = _str(f, 'status');
    return s != null ? TuneStatus.values.byName(s) : null;
  }

  TuneType? _tuneType(Map<String, dynamic> f) {
    final s = _str(f, 'type');
    return s != null ? TuneType.values.byName(s) : null;
  }

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
