// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tune_dao.dart';

// ignore_for_file: type=lint
mixin _$TuneDaoMixin on DatabaseAccessor<AppDatabase> {
  $TunesTable get tunes => attachedDatabase.tunes;
  TuneDaoManager get managers => TuneDaoManager(this);
}

class TuneDaoManager {
  final _$TuneDaoMixin _db;
  TuneDaoManager(this._db);
  $$TunesTableTableManager get tunes =>
      $$TunesTableTableManager(_db.attachedDatabase, _db.tunes);
}
