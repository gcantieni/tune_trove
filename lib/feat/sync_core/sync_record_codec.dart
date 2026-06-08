// package imports
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/model/database.dart';

/// The transport-neutral, canonical serialization of the local database.
///
/// A *record* is a `Map<String, dynamic>` with a `recordType`, a `cloudId`, and
/// snake_case field keys; timestamps are ms-since-epoch integers and enums are
/// their string `name`. Join-table records carry the cloud_ids of their parent
/// rows (`tune_cloud_id`, `recording_cloud_id`, `set_cloud_id`) so foreign keys
/// resolve on the receiving side regardless of local integer ids.
///
/// This format is shared by every sync transport — CloudKit, the file/ZIP
/// backup, and any future cloud-drive backend — via [serializeAll] on the way
/// out and [recordsToFetchedChanges] + [SyncReconciliationService] on the way
/// in. Keep it in lockstep with the inbound reconciliation.

/// Canonical record-type names.
const tuneRecordType = 'Tune';
const recordingRecordType = 'Recording';
const tuneRecordingRecordType = 'TuneRecording';
const tuneSetRecordType = 'TuneSet';
const setTuneRecordType = 'SetTune';
const sourceConfirmationRecordType = 'SourceConfirmation';
const sourceRankingRecordType = 'SourceRanking';
const appSettingRecordType = 'AppSetting';

/// Every record type the canonical format knows how to serialize.
const allSyncRecordTypes = <String>{
  tuneRecordType,
  recordingRecordType,
  tuneRecordingRecordType,
  tuneSetRecordType,
  setTuneRecordType,
  sourceConfirmationRecordType,
  sourceRankingRecordType,
  appSettingRecordType,
};

/// Serializes every row in [db] into canonical records, restricted to
/// [recordTypes] (pass [allSyncRecordTypes] for a full snapshot). Required so a
/// transport's scope is always an explicit, reviewable decision.
///
/// Join-table records include the cloud_ids of their parent rows so the
/// receiving side can resolve foreign keys. Rows missing a cloud_id are skipped
/// (should not happen after the v9 migration, but handled defensively); a join
/// whose parents are excluded or missing a cloud_id is dropped too.
Future<List<Map<String, dynamic>>> serializeAll(
  AppDatabase db, {
  required Set<String> recordTypes,
}) async {
  final records = <Map<String, dynamic>>[];

  // Read the base tables up front to build id→row maps for O(1) lookups when
  // serializing join tables.
  final tunes = await db.tuneDao.getAll();
  final recs = await db.recordingDao.getAll();
  final sets = await db.setDao.getAll();
  final tuneById = {for (final t in tunes) t.id: t};
  final recById = {for (final r in recs) r.id: r};
  final setById = {for (final s in sets) s.id: s};

  if (recordTypes.contains(tuneRecordType)) {
    for (final t in tunes) {
      if (t.cloudId == null) continue;
      records.add(serializeTune(t));
    }
  }

  if (recordTypes.contains(recordingRecordType)) {
    for (final r in recs) {
      if (r.cloudId == null) continue;
      records.add(serializeRecording(r));
    }
  }

  if (recordTypes.contains(tuneRecordingRecordType)) {
    for (final tr in await db.tuneRecordingDao.getAll()) {
      if (tr.cloudId == null) continue;
      final tune = tuneById[tr.tuneId];
      final rec = recById[tr.recordingId];
      if (tune?.cloudId == null || rec?.cloudId == null) continue;
      records.add(
        serializeTuneRecording(
          tr,
          tuneCloudId: tune!.cloudId!,
          recordingCloudId: rec!.cloudId!,
        ),
      );
    }
  }

  if (recordTypes.contains(tuneSetRecordType)) {
    for (final s in sets) {
      if (s.cloudId == null) continue;
      records.add(serializeTuneSet(s));
    }
  }

  if (recordTypes.contains(setTuneRecordType)) {
    for (final st in await db.setTuneDao.getAll()) {
      if (st.cloudId == null) continue;
      final tuneSet = setById[st.setId];
      final tune = tuneById[st.tuneId];
      if (tuneSet?.cloudId == null || tune?.cloudId == null) continue;
      records.add(
        serializeSetTune(
          st,
          setCloudId: tuneSet!.cloudId!,
          tuneCloudId: tune!.cloudId!,
        ),
      );
    }
  }

  if (recordTypes.contains(sourceConfirmationRecordType)) {
    for (final c in await db.sourceConfirmationDao.getAll()) {
      if (c.cloudId == null) continue;
      records.add(serializeSourceConfirmation(c));
    }
  }

  if (recordTypes.contains(sourceRankingRecordType)) {
    for (final r in await db.sourceRankingsDao.getAll()) {
      if (r.cloudId == null) continue;
      records.add(serializeSourceRanking(r));
    }
  }

  if (recordTypes.contains(appSettingRecordType)) {
    for (final s in await db.appSettingsDao.getAll()) {
      if (s.cloudId == null) continue;
      records.add(serializeAppSetting(s));
    }
  }

  return records;
}

/// Wraps a list of canonical [records] as an all-upserts [FetchedChanges] so any
/// transport's "pull" can feed [SyncReconciliationService.applyFetched]. The
/// record map is passed through as the event's `fields` (the extra `recordType`
/// key is harmless — reconciliation reads fields by name).
FetchedChanges recordsToFetchedChanges(List<Map<String, dynamic>> records) {
  final upserts = [
    for (final r in records)
      SyncUpsertEvent(r['recordType'] as String, r),
  ];
  return FetchedChanges(upserts, const []);
}

// ---------------------------------------------------------------------------
// Per-type serializers
// ---------------------------------------------------------------------------

Map<String, dynamic> serializeTune(Tune t) => {
  'recordType': tuneRecordType,
  'cloudId': t.cloudId,
  'name': t.name,
  if (t.abc != null) 'abc': t.abc,
  if (t.tsId != null) 'ts_id': t.tsId,
  if (t.from != null) 'from': t.from,
  if (t.source != null) 'source': t.source,
  if (t.composer != null) 'composer': t.composer,
  if (t.status != null) 'status': t.status!.name,
  if (t.key != null) 'key': t.key,
  if (t.type != null) 'type': t.type!.name,
  if (t.genre != null) 'genre': t.genre,
  'created_at': t.createdAt.millisecondsSinceEpoch,
  if (t.modifiedAt != null) 'modified_at': t.modifiedAt!.millisecondsSinceEpoch,
};

Map<String, dynamic> serializeRecording(Recording r) => {
  'recordType': recordingRecordType,
  'cloudId': r.cloudId,
  'name': r.name,
  'url': r.url,
  if (r.performers != null) 'performers': r.performers,
  'created_at': r.createdAt.millisecondsSinceEpoch,
  if (r.modifiedAt != null) 'modified_at': r.modifiedAt!.millisecondsSinceEpoch,
};

Map<String, dynamic> serializeTuneRecording(
  TuneRecordingData tr, {
  required String tuneCloudId,
  required String recordingCloudId,
}) => {
  'recordType': tuneRecordingRecordType,
  'cloudId': tr.cloudId,
  'tune_cloud_id': tuneCloudId,
  'recording_cloud_id': recordingCloudId,
  // start_time / end_time are audio-position seconds (double), not dates.
  if (tr.startTime != null) 'start_time': tr.startTime,
  if (tr.endTime != null) 'end_time': tr.endTime,
  if (tr.performers != null) 'performers': tr.performers,
  if (tr.performedKey != null) 'performed_key': tr.performedKey,
};

Map<String, dynamic> serializeTuneSet(TuneSet s) => {
  'recordType': tuneSetRecordType,
  'cloudId': s.cloudId,
  'name': s.name,
  'position': s.position,
  'created_at': s.createdAt.millisecondsSinceEpoch,
  if (s.modifiedAt != null) 'modified_at': s.modifiedAt!.millisecondsSinceEpoch,
};

Map<String, dynamic> serializeSetTune(
  SetTuneData st, {
  required String setCloudId,
  required String tuneCloudId,
}) => {
  'recordType': setTuneRecordType,
  'cloudId': st.cloudId,
  'set_cloud_id': setCloudId,
  'tune_cloud_id': tuneCloudId,
  'position': st.position,
  if (st.key != null) 'key': st.key,
};

Map<String, dynamic> serializeSourceConfirmation(SourceConfirmation c) => {
  'recordType': sourceConfirmationRecordType,
  'cloudId': c.cloudId,
  'source_id': c.sourceId,
  if (c.license != null) 'license': c.license,
  'created_at': c.createdAt.millisecondsSinceEpoch,
  if (c.modifiedAt != null) 'modified_at': c.modifiedAt!.millisecondsSinceEpoch,
};

Map<String, dynamic> serializeSourceRanking(SourceRanking r) => {
  'recordType': sourceRankingRecordType,
  'cloudId': r.cloudId,
  'source_id': r.sourceId,
  'rank': r.rank,
  if (r.modifiedAt != null) 'modified_at': r.modifiedAt!.millisecondsSinceEpoch,
};

Map<String, dynamic> serializeAppSetting(AppSetting s) => {
  'recordType': appSettingRecordType,
  'cloudId': s.cloudId,
  'key': s.key,
  'value': s.value,
  if (s.modifiedAt != null) 'modified_at': s.modifiedAt!.millisecondsSinceEpoch,
};
