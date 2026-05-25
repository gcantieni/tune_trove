import 'package:drift/drift.dart';

class TuneSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();
  TextColumn get cloudId => text().nullable()();
}
