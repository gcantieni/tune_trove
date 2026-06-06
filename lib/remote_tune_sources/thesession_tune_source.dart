import 'package:tune_trove/model/tables/tunes.dart';

TuneType stringToType(String s) {
  switch (s) {
    case "jig":
      return TuneType.jig;
    case "reel":
      return TuneType.reel;
    case "polka":
      return TuneType.polka;
    case "slide":
      return TuneType.slide;
    case "hornpipe":
      return TuneType.hornpipe;
    case "march":
      return TuneType.march;
    case "slip jig":
      return TuneType.slipJig;
    case "waltz":
      return TuneType.waltz;
    case "barndance":
      return TuneType.barndance;
    case "strathspey":
      return TuneType.strathspey;
    case "three-two":
      return TuneType.threeTwo;
    case "mazurka":
      return TuneType.mazurka;
    default:
      throw Exception("Unsupported tune type $s");
  }
}
