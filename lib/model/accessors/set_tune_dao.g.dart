// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_tune_dao.dart';

// ignore_for_file: type=lint
mixin _$SetTuneDaoMixin on DatabaseAccessor<AppDatabase> {
  $TuneSetsTable get tuneSets => attachedDatabase.tuneSets;
  $TunesTable get tunes => attachedDatabase.tunes;
  $SetTuneTable get setTune => attachedDatabase.setTune;
  SetTuneDaoManager get managers => SetTuneDaoManager(this);
}

class SetTuneDaoManager {
  final _$SetTuneDaoMixin _db;
  SetTuneDaoManager(this._db);
  $$TuneSetsTableTableManager get tuneSets =>
      $$TuneSetsTableTableManager(_db.attachedDatabase, _db.tuneSets);
  $$TunesTableTableManager get tunes =>
      $$TunesTableTableManager(_db.attachedDatabase, _db.tunes);
  $$SetTuneTableTableManager get setTune =>
      $$SetTuneTableTableManager(_db.attachedDatabase, _db.setTune);
}
