import 'package:drift/drift.dart';

class TuneRecording extends Table {
  IntColumn get tuneId => integer()();
  IntColumn get recordingId => integer()();

  /// Start timestamp in seconds
  IntColumn get startTime => integer().nullable()();

  /// End timestamp in seconds
  IntColumn get endTime => integer().nullable()();

  /// Free text for names of performers if known
  TextColumn get performers => text().nullable()();

  /// Key the tune was performed in on this recording (may differ from the
  /// tune's canonical key, e.g. a session recorded in G vs. the usual D)
  TextColumn get performedKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {tuneId, recordingId};
}
