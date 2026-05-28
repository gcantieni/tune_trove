// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_rankings_dao.dart';

// ignore_for_file: type=lint
mixin _$SourceRankingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SourceRankingsTable get sourceRankings => attachedDatabase.sourceRankings;
  SourceRankingsDaoManager get managers => SourceRankingsDaoManager(this);
}

class SourceRankingsDaoManager {
  final _$SourceRankingsDaoMixin _db;
  SourceRankingsDaoManager(this._db);
  $$SourceRankingsTableTableManager get sourceRankings =>
      $$SourceRankingsTableTableManager(
        _db.attachedDatabase,
        _db.sourceRankings,
      );
}
