// Test co-located in lib/ (no test/ tree), so the analyzer cannot treat it
// as a test for @visibleForTesting purposes.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/playback_card.dart';

void main() {
  group('loopBoundsAfterSnap', () {
    test('snapping the start thumb moves start to the playback position', () {
      final (start, end) = loopBoundsAfterSnap(
        isStart: true,
        position: 12.0,
        loopStart: 5,
        loopEnd: 30,
        duration: 60,
      );
      expect(start, 12.0);
      expect(end, 30.0); // unchanged
    });

    test('snapping the end thumb moves end to the playback position', () {
      final (start, end) = loopBoundsAfterSnap(
        isStart: false,
        position: 25.0,
        loopStart: 5,
        loopEnd: 30,
        duration: 60,
      );
      expect(start, 5.0); // unchanged
      expect(end, 25.0);
    });

    test('start cannot be dragged past the end thumb', () {
      final (start, end) = loopBoundsAfterSnap(
        isStart: true,
        position: 45.0, // beyond the end thumb at 30
        loopStart: 5,
        loopEnd: 30,
        duration: 60,
      );
      expect(start, 30.0); // clamped to the end thumb
      expect(end, 30.0);
    });

    test('end cannot be dragged before the start thumb', () {
      final (start, end) = loopBoundsAfterSnap(
        isStart: false,
        position: 2.0, // before the start thumb at 5
        loopStart: 5,
        loopEnd: 30,
        duration: 60,
      );
      expect(start, 5.0);
      expect(end, 5.0); // clamped to the start thumb
    });

    test('position is clamped to the track duration', () {
      final (_, end) = loopBoundsAfterSnap(
        isStart: false,
        position: 999.0,
        loopStart: 5,
        loopEnd: 30,
        duration: 60,
      );
      expect(end, 60.0);
    });
  });
}
