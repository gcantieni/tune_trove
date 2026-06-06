import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/tables/tunes.dart' show TuneType;
import 'package:tune_trove/util/abc_metadata.dart';

void main() {
  group('parseAbcMetadata', () {
    test('parses R/C/O from a typical header', () {
      const abc = '''
X:1
T:The Sample
R:Hornpipe
C:Turlough O'Carolan
O:Ireland
M:4/4
K:Dmaj
|: A B c d :|
''';
      final meta = parseAbcMetadata(abc);
      expect(meta.type, TuneType.hornpipe);
      expect(meta.composer, "Turlough O'Carolan");
      expect(meta.genre, 'Irish');
    });

    test('treats Trad. as no composer', () {
      const abc = 'X:1\nR:Reel\nC:Trad.\nO:Scotland\nK:Amaj';
      final meta = parseAbcMetadata(abc);
      expect(meta.type, TuneType.reel);
      expect(meta.composer, isNull);
      expect(meta.genre, 'Scottish');
    });

    for (final c in ['Traditional', 'Anon', 'Anonymous', 'Unknown', 'trad']) {
      test('"$c" maps to no composer', () {
        expect(parseAbcMetadata('C:$c').composer, isNull);
      });
    }

    test('empty ABC yields empty metadata', () {
      final meta = parseAbcMetadata('X:1\nK:Dmaj');
      expect(meta.isEmpty, isTrue);
    });

    group('rhythm → type', () {
      const cases = {
        'Reel': TuneType.reel,
        'reels': TuneType.reel,
        'Jig': TuneType.jig,
        'Double Jig': TuneType.jig,
        'Hornpipe': TuneType.hornpipe,
        'Polka': TuneType.polka,
        'Slide': TuneType.slide,
        'March': TuneType.march,
        'Slip Jig': TuneType.slipJig,
        'slipjig': TuneType.slipJig,
        'Hop Jig': TuneType.slipJig,
        'Barndance': TuneType.barndance,
        'Barn Dance': TuneType.barndance,
        'Waltz': TuneType.waltz,
        'Strathspey': TuneType.strathspey,
        'Three-Two': TuneType.threeTwo,
        '3/2': TuneType.threeTwo,
        'Mazurka': TuneType.mazurka,
      };
      cases.forEach((rhythm, type) {
        test('R:$rhythm → $type', () {
          expect(parseAbcMetadata('R:$rhythm').type, type);
        });
      });

      test('unknown rhythm yields null type', () {
        expect(parseAbcMetadata('R:Foxtrot').type, isNull);
      });
    });

    group('origin → genre', () {
      const cases = {
        'Ireland': 'Irish',
        'Scotland': 'Scottish',
        'England': 'English',
        'Wales': 'Welsh',
        'Sweden': 'Swedish',
        'Quebec': 'Quebecois',
        'Cape Breton': 'Cape Breton',
        'Irish': 'Irish', // already an adjective
        'Old-time': 'Old-time',
        'Shetland': 'Shetland',
        // Phrases: a known place matched as a whole word within free text.
        'The Shetland Islands': 'Shetland',
        'Co. Clare, Ireland': 'Irish',
        // "New England" must win over the "England" keyword it contains.
        'New England': 'New England',
        'New England, USA': 'New England',
        // Breton (Brittany) vs Cape Breton must not be confused.
        'Breton': 'Breton',
        'Brittany': 'Breton',
        'Bretagne, France': 'Breton',
        'Cape Breton Island, Nova Scotia': 'Cape Breton',
      };
      cases.forEach((origin, genre) {
        test('O:$origin → $genre', () {
          expect(parseAbcMetadata('O:$origin').genre, genre);
        });
      });

      test('unknown origin yields null genre', () {
        expect(parseAbcMetadata('O:Atlantis').genre, isNull);
      });
    });
  });
}
