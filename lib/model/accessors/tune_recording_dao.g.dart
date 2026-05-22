// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tune_recording_dao.dart';

// ignore_for_file: type=lint
mixin _$TuneRecordingDaoMixin on DatabaseAccessor<AppDatabase> {
  $TuneRecordingTable get tuneRecording => attachedDatabase.tuneRecording;
  $TunesTable get tunes => attachedDatabase.tunes;
  $RecordingsTable get recordings => attachedDatabase.recordings;
  TuneRecordingDaoManager get managers => TuneRecordingDaoManager(this);
}

class TuneRecordingDaoManager {
  final _$TuneRecordingDaoMixin _db;
  TuneRecordingDaoManager(this._db);
  $$TuneRecordingTableTableManager get tuneRecording =>
      $$TuneRecordingTableTableManager(_db.attachedDatabase, _db.tuneRecording);
  $$TunesTableTableManager get tunes =>
      $$TunesTableTableManager(_db.attachedDatabase, _db.tunes);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
}
