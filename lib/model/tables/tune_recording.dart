import 'package:drift/drift.dart';

class TuneRecording extends Table {
  IntColumn get tuneId => integer()();
  IntColumn get recordingId => integer()();

  /// Start timestamp in seconds (fractional, hundredths precision)
  RealColumn get startTime => real().nullable()();

  /// End timestamp in seconds (fractional, hundredths precision)
  RealColumn get endTime => real().nullable()();

  /// Free text for names of performers if known
  TextColumn get performers => text().nullable()();

  /// Key the tune was performed in on this recording (may differ from the
  /// tune's canonical key, e.g. a session recorded in G vs. the usual D)
  TextColumn get performedKey => text().nullable()();

  TextColumn get cloudId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {tuneId, recordingId};
}
