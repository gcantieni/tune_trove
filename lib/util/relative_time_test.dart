import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/util/relative_time.dart';

void main() {
  final now = DateTime(2026, 6, 4, 12);

  group('relativeAge', () {
    test('today / yesterday', () {
      expect(relativeAge(DateTime(2026, 6, 4, 8), now: now), 'today');
      expect(relativeAge(DateTime(2026, 6, 3, 8), now: now), 'yesterday');
    });

    test('days', () {
      expect(relativeAge(DateTime(2026, 6, 1, 12), now: now), '3 days ago');
    });

    test('weeks', () {
      expect(relativeAge(DateTime(2026, 5, 20), now: now), '2 weeks ago');
      expect(relativeAge(DateTime(2026, 5, 26), now: now), '1 week ago');
    });

    test('months', () {
      expect(relativeAge(DateTime(2026, 4, 1, 12), now: now), '2 months ago');
      expect(relativeAge(DateTime(2026, 5, 1, 12), now: now), '1 month ago');
    });

    test('years', () {
      expect(relativeAge(DateTime(2023, 6, 4), now: now), '3 years ago');
      expect(relativeAge(DateTime(2025, 5, 1, 12), now: now), '1 year ago');
    });

    test('future dates degrade gracefully', () {
      expect(relativeAge(DateTime(2027, 1, 1, 12), now: now), 'in the future');
    });
  });
}
