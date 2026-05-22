// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordingDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecordingsTable get recordings => attachedDatabase.recordings;
  RecordingDaoManager get managers => RecordingDaoManager(this);
}

class RecordingDaoManager {
  final _$RecordingDaoMixin _db;
  RecordingDaoManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db.attachedDatabase, _db.recordings);
}
