import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/util/uuid.dart';

void main() {
  group('generateUuid', () {
    final v4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('produces canonical 36-character form', () {
      final uuid = generateUuid();
      expect(uuid.length, equals(36));
      expect(uuid.split('-'), hasLength(5));
    });

    test('matches RFC 4122 version-4 pattern', () {
      for (var i = 0; i < 50; i++) {
        expect(generateUuid(), matches(v4Pattern));
      }
    });

    test('sets the version nibble to 4', () {
      expect(generateUuid()[14], equals('4'));
    });

    test('sets the variant nibble to one of 8/9/a/b', () {
      expect(generateUuid()[19], anyOf('8', '9', 'a', 'b'));
    });

    test('generates unique values', () {
      final ids = List.generate(1000, (_) => generateUuid()).toSet();
      expect(ids, hasLength(1000));
    });
  });
}
