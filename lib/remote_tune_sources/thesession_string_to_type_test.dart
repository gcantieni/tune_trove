import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/tables/tunes.dart' show TuneType;
import 'package:tune_trove/remote_tune_sources/thesession_tune_source.dart';

void main() {
  group('stringToType', () {
    test('jig', () => expect(stringToType('jig'), TuneType.jig));
    test('reel', () => expect(stringToType('reel'), TuneType.reel));
    test('polka', () => expect(stringToType('polka'), TuneType.polka));
    test('slide', () => expect(stringToType('slide'), TuneType.slide));
    test('hornpipe', () => expect(stringToType('hornpipe'), TuneType.hornpipe));
    test('march', () => expect(stringToType('march'), TuneType.march));
    test('slip jig', () => expect(stringToType('slip jig'), TuneType.slipJig));
    test('waltz', () => expect(stringToType('waltz'), TuneType.waltz));
    test('barndance', () => expect(stringToType('barndance'), TuneType.barndance));
    test('strathspey', () => expect(stringToType('strathspey'), TuneType.strathspey));
    test('three-two', () => expect(stringToType('three-two'), TuneType.threeTwo));
    test('mazurka', () => expect(stringToType('mazurka'), TuneType.mazurka));
    test('unknown throws Exception', () {
      expect(() => stringToType('unknown'), throwsA(isA<Exception>()));
    });
  });
}
