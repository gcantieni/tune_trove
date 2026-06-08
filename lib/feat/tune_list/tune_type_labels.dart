import 'package:tune_trove/model/tables/tunes.dart';

/// Human-friendly display labels for [TuneType]. The enum names alone are
/// machine-ish (`slipJig`, `threeTwo`); these give the singular and plural forms
/// used in the UI (e.g. section headers like "Scottish Jigs").

/// Singular display label, e.g. `slipJig → "Slip jig"`.
String tuneTypeLabel(TuneType type) => switch (type) {
  TuneType.reel => 'Reel',
  TuneType.jig => 'Jig',
  TuneType.hornpipe => 'Hornpipe',
  TuneType.polka => 'Polka',
  TuneType.slide => 'Slide',
  TuneType.march => 'March',
  TuneType.slipJig => 'Slip jig',
  TuneType.barndance => 'Barndance',
  TuneType.waltz => 'Waltz',
  TuneType.strathspey => 'Strathspey',
  TuneType.threeTwo => 'Three-two',
  TuneType.mazurka => 'Mazurka',
};

/// Plural display label, e.g. `slipJig → "Slip jigs"`, `march → "Marches"`.
String tuneTypePlural(TuneType type) => switch (type) {
  TuneType.reel => 'Reels',
  TuneType.jig => 'Jigs',
  TuneType.hornpipe => 'Hornpipes',
  TuneType.polka => 'Polkas',
  TuneType.slide => 'Slides',
  TuneType.march => 'Marches',
  TuneType.slipJig => 'Slip jigs',
  TuneType.barndance => 'Barndances',
  TuneType.waltz => 'Waltzes',
  TuneType.strathspey => 'Strathspeys',
  TuneType.threeTwo => 'Three-twos',
  TuneType.mazurka => 'Mazurkas',
};
