import 'package:drift/drift.dart';

import 'package:tune_trove/model/tables/sets.dart';
import 'package:tune_trove/model/tables/tunes.dart';

class SetTune extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setId => integer().references(TuneSets, #id)();
  IntColumn get tuneId => integer().references(Tunes, #id)();
  IntColumn get position => integer()();
  TextColumn get key => text().nullable()();
  TextColumn get cloudId => text().nullable()();
}
