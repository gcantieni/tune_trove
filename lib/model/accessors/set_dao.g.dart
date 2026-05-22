// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_dao.dart';

// ignore_for_file: type=lint
mixin _$SetDaoMixin on DatabaseAccessor<AppDatabase> {
  $TuneSetsTable get tuneSets => attachedDatabase.tuneSets;
  SetDaoManager get managers => SetDaoManager(this);
}

class SetDaoManager {
  final _$SetDaoMixin _db;
  SetDaoManager(this._db);
  $$TuneSetsTableTableManager get tuneSets =>
      $$TuneSetsTableTableManager(_db.attachedDatabase, _db.tuneSets);
}
