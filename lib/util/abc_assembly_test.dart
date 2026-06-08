import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/util/abc_assembly.dart';

void main() {
  group('normalizeKeyForAbc', () {
    const cases = {
      'Gmajor': 'G', // major → bare tonic
      'Dmaj': 'D',
      'D': 'D',
      'Edorian': 'Edor',
      'Edor': 'Edor',
      'Aminor': 'Amin',
      'Am': 'Amin',
      'Bmixolydian': 'Bmix',
      'F#minor': 'F#min',
      'Bb': 'Bb',
      'Bbmajor': 'Bb',
      'Glydian': 'Glyd',
      'Cphrygian': 'Cphr',
      'Blocrian': 'Bloc',
    };
    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () {
        expect(normalizeKeyForAbc(input), expected);
      });
    });

    test('null / empty / unparseable → null', () {
      expect(normalizeKeyForAbc(null), isNull);
      expect(normalizeKeyForAbc(''), isNull);
      expect(normalizeKeyForAbc('   '), isNull);
      expect(normalizeKeyForAbc('none'), isNull);
    });
  });

  group('assembleAbc', () {
    test('injects a full header when the body has none', () {
      final out = assembleAbc('|:G>A B>G:|', key: 'Gmajor');
      expect(out, contains('K:G'));
      expect(out, contains('X:1'));
      expect(out, contains('M:4/4'));
      expect(out, contains('L:1/8'));
      expect(out!.trimRight(), endsWith('|:G>A B>G:|'));
    });

    test('preserves an existing K: header (idempotent)', () {
      const full = 'X:1\nT:Already\nM:4/4\nL:1/8\nK:Dmaj\n|:ABcd:|';
      expect(assembleAbc(full, key: 'Amajor'), full);
    });

    test('calling twice does not double the header', () {
      final once = assembleAbc('|:abc:|', key: 'Edorian');
      final twice = assembleAbc(once, key: 'Edorian');
      expect(twice, once);
      expect('K:'.allMatches(once!).length, 1);
    });

    test('does not duplicate a partial header (X:/M:/L: present, K: absent)', () {
      final out = assembleAbc('X:1\nM:6/8\nL:1/8\n|:abc:|', key: 'Ador');
      expect('X:'.allMatches(out!).length, 1);
      expect('M:'.allMatches(out).length, 1);
      expect(out, contains('M:6/8')); // keeps the body's own meter
      expect(out, contains('K:Ador'));
    });

    test('returns input unchanged when key is unparseable', () {
      expect(assembleAbc('|:abc:|'), '|:abc:|');
      expect(assembleAbc('|:abc:|', key: 'mystery'), '|:abc:|');
    });

    test('preserves null / blank abc', () {
      expect(assembleAbc(null, key: 'Dmaj'), isNull);
      expect(assembleAbc('', key: 'Dmaj'), '');
      expect(assembleAbc('   ', key: 'Dmaj'), '   ');
    });
  });
}
