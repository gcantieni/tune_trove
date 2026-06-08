import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';

void main() {
  // Active ids for tests: always-active sources + confirmed sources.
  const activeIds = {
    'pete_mac', // always-active (CC0)
    'williamclarke', // always-active (public domain)
    'oneills_1001', // confirmed
    'thesession', // confirmed
  };

  group('isSourceIdVisible', () {
    test('null source → always visible (user-created tune)', () {
      expect(isSourceIdVisible(null, activeIds), isTrue);
    });

    test('empty string source → always visible', () {
      expect(isSourceIdVisible('', activeIds), isTrue);
    });

    test('unknown source id → always visible (e.g. newer app version)', () {
      expect(isSourceIdVisible('some_future_source', activeIds), isTrue);
    });

    test('always-active source → visible without confirmation', () {
      expect(isSourceIdVisible('pete_mac', activeIds), isTrue);
      expect(isSourceIdVisible('williamclarke', activeIds), isTrue);
    });

    test('confirmed source → visible', () {
      expect(isSourceIdVisible('oneills_1001', activeIds), isTrue);
      expect(isSourceIdVisible('thesession', activeIds), isTrue);
    });

    test('unconfirmed source → not visible', () {
      expect(isSourceIdVisible('norbeck', activeIds), isFalse);
      expect(isSourceIdVisible('paulhardy', activeIds), isFalse);
      expect(isSourceIdVisible('athole', activeIds), isFalse);
    });

    test('unconfirmed source not visible even with empty active set', () {
      expect(isSourceIdVisible('norbeck', {}), isFalse);
    });

    test('source becomes visible when added to active set', () {
      final extended = {...activeIds, 'norbeck'};
      expect(isSourceIdVisible('norbeck', extended), isTrue);
    });
  });
}
