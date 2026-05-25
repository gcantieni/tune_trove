import 'package:drift/drift.dart';

class Recordings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  // Convention: never store absolute filesystem paths here. Use a URI scheme
  // (e.g. https://, spotify:, app-data:relative/path) so values stay portable
  // across devices and OS reinstalls.
  TextColumn get url => text()();

  TextColumn get performers => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();
  TextColumn get cloudId => text().nullable()();
}
