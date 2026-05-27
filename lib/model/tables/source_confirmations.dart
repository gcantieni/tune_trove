import 'package:drift/drift.dart';

/// One row per content source the user has confirmed (accepted the license
/// dialog for). Synced via CloudKit so a confirmation made on one device
/// activates the source on the user's other devices.
class SourceConfirmations extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The content source id (e.g. 'thesession'). Natural cross-device key.
  TextColumn get sourceId => text()();

  /// The license string acknowledged at confirmation time.
  TextColumn get license => text().nullable()();

  /// When the source was confirmed (acts as the created/“first seen” time).
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();

  TextColumn get cloudId => text().nullable()();
}
