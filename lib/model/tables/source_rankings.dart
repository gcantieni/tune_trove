import 'package:drift/drift.dart';

/// One row per active content source, ordered by [rank] (ascending = first in
/// search results). Synced via CloudKit so reordering on one device propagates
/// to the user's other devices.
class SourceRankings extends Table {
  TextColumn get sourceId => text()();
  IntColumn get rank => integer()();
  TextColumn get cloudId => text().nullable()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId};
}
