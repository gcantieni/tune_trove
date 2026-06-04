import 'package:drift/drift.dart';

enum TuneStatus { todo, canPlay, canStart, inSet, mastered }

extension TuneStatusProgression on TuneStatus {
  /// Learning-progression rank (higher = more learned). Matches the dot
  /// count shown in the tune list, and is the single source of truth for
  /// ordering tunes by learning status.
  int get progressionRank => switch (this) {
    TuneStatus.todo => 1,
    TuneStatus.canPlay => 2,
    TuneStatus.canStart => 3,
    TuneStatus.inSet => 4,
    TuneStatus.mastered => 5,
  };
}

// TODO: expand
enum TuneType {
  reel,
  jig,
  hornpipe,
  polka,
  slide,
  march,
  slipJig,
  barndance,
  waltz,
  strathspey,
  threeTwo,
  mazurka,
}

class Tunes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get abc => text().nullable()(); // ABC notation of the tune
  // Cached SVG rendering of `abc`, produced by lib/feat/abc_render. Nullable
  // because rendering happens after the row is written, and may fail
  // (offline first-run, malformed ABC). Cleared and re-rendered on
  // every update to `abc`. If the abc_render module is removed, this
  // column can be dropped — nothing else reads it.
  TextColumn get abcSvg => text().nullable()();
  IntColumn get tsId =>
      integer().nullable()(); // ID of the tune on thesession.com
  TextColumn get from => text().nullable()(); // Who I learned the tune from
  TextColumn get composer =>
      text().nullable()(); // Who wrote the tune (royalty attribution)
  TextColumn get status =>
      textEnum<TuneStatus>().nullable()(); // How well is a tune known
  TextColumn get key => text().nullable()();
  TextColumn get type =>
      textEnum<TuneType>().nullable()(); // How well is a tune known
  TextColumn get genre => text().nullable()(); // e.g. Irish, oldtime, Scottish
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime().nullable()();
  TextColumn get cloudId => text().nullable()();
}
