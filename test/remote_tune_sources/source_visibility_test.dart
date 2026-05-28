import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';

void main() {
  // Active names for tests: always-active sources + confirmed sources.
  const activeNames = {
    'Pete Mac Tunebook', // always-active (CC0)
    'William Clarke of Feltwell', // always-active (public domain)
    "O'Neill's 1001", // confirmed
    'thesession.org', // confirmed
  };

  group('isSourceNameVisible', () {
    test('null from → always visible (user-created tune)', () {
      expect(isSourceNameVisible(null, activeNames), isTrue);
    });

    test('empty string from → always visible', () {
      expect(isSourceNameVisible('', activeNames), isTrue);
    });

    test('unknown/user-typed from → always visible', () {
      expect(isSourceNameVisible('My Own Book', activeNames), isTrue);
    });

    test('always-active source → visible without confirmation', () {
      expect(isSourceNameVisible('Pete Mac Tunebook', activeNames), isTrue);
      expect(isSourceNameVisible('William Clarke of Feltwell', activeNames), isTrue);
    });

    test('confirmed source → visible', () {
      expect(isSourceNameVisible("O'Neill's 1001", activeNames), isTrue);
      expect(isSourceNameVisible('thesession.org', activeNames), isTrue);
    });

    test('unconfirmed source → not visible', () {
      expect(isSourceNameVisible('Norbeck', activeNames), isFalse);
      expect(isSourceNameVisible('Paul Hardy Session Tunebook', activeNames), isFalse);
      expect(isSourceNameVisible('The Athole Collection (1884)', activeNames), isFalse);
    });

    test('unconfirmed source not visible even with empty active set', () {
      expect(isSourceNameVisible('Norbeck', {}), isFalse);
    });

    test('source becomes visible when added to active set', () {
      final extended = {...activeNames, 'Norbeck'};
      expect(isSourceNameVisible('Norbeck', extended), isTrue);
    });
  });
}
