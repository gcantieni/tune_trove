import 'package:drift/drift.dart' as drift;
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';

List<TunesCompanion> parseTunes(List<Map<String, dynamic>> data) {
  return data.map((entry) {
    return TunesCompanion.insert(
      name: entry['name'] as String,
      createdAt: DateTime.now(),
      from: const drift.Value(null),
      tsId: drift.Value(entry['id'] as int),
      abc: drift.Value(entry['abc'] as String),
      key: drift.Value(entry['key'] as String),
      type: drift.Value(stringToType(entry['type'] as String)),
    );
  }).toList();
}

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
