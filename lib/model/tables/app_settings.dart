import 'package:drift/drift.dart';

/// Generic key-value store for user preferences (e.g. whether to invert sheet
/// music in dark mode). One row per setting, keyed by [key]. Synced via
/// CloudKit so a preference changed on one device propagates to the user's
/// other devices (last-writer-wins by [modifiedAt]).
class AppSettings extends Table {
  /// The setting key (natural cross-device key).
  TextColumn get key => text()();

  /// The setting value, stored as a string ('true'/'false' for bools, etc.).
  TextColumn get value => text()();

  TextColumn get cloudId => text().nullable()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
