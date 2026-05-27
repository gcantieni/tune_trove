// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_confirmation_dao.dart';

// ignore_for_file: type=lint
mixin _$SourceConfirmationDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourceConfirmationsTable get sourceConfirmations =>
      attachedDatabase.sourceConfirmations;
  SourceConfirmationDaoManager get managers =>
      SourceConfirmationDaoManager(this);
}

class SourceConfirmationDaoManager {
  final _$SourceConfirmationDaoMixin _db;
  SourceConfirmationDaoManager(this._db);
  $$SourceConfirmationsTableTableManager get sourceConfirmations =>
      $$SourceConfirmationsTableTableManager(
        _db.attachedDatabase,
        _db.sourceConfirmations,
      );
}
