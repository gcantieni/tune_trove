import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/shared_widgets/timestamp_editor_dialog.dart';

void main() {
  group('formatTime', () {
    test('null renders an em-dash placeholder', () {
      expect(formatTime(null), '—:—');
    });

    test('formats minutes, seconds, and centiseconds', () {
      expect(formatTime(0), '0:00.00');
      expect(formatTime(65.5), '1:05.50');
      expect(formatTime(12.34), '0:12.34');
      expect(formatTime(125), '2:05.00');
    });

    test('zero-pads seconds and centiseconds', () {
      expect(formatTime(61.05), '1:01.05');
    });
  });

  group('parseTime', () {
    test('parses m:ss.cc', () {
      expect(parseTime('1:05.50'), closeTo(65.5, 1e-9));
      expect(parseTime('0:12.34'), closeTo(12.34, 1e-9));
    });

    test('parses m:ss without centiseconds', () {
      expect(parseTime('1:05'), 65.0);
      expect(parseTime('2:00'), 120.0);
    });

    test('parses bare seconds', () {
      expect(parseTime('90'), 90.0);
      expect(parseTime('12.5'), closeTo(12.5, 1e-9));
    });

    test('blank input returns null', () {
      expect(parseTime(''), isNull);
      expect(parseTime('   '), isNull);
    });

    test('rejects out-of-range and malformed values', () {
      expect(parseTime('1:90'), isNull); // seconds >= 60
      expect(parseTime('-1:00'), isNull); // negative minutes
      expect(parseTime('1:2:3'), isNull); // too many colon parts
      expect(parseTime('1:0.5.5'), isNull); // too many dot parts
      expect(parseTime('abc'), isNull); // non-numeric
      expect(parseTime('-5'), isNull); // negative seconds
    });

    test('round-trips with formatTime', () {
      for (final sec in [0.0, 12.34, 65.5, 125.0]) {
        expect(parseTime(formatTime(sec)), closeTo(sec, 1e-9));
      }
    });
  });
}
