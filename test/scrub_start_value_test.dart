import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/playback_card.dart';

void main() {
  group('scrubStartValue', () {
    // 100px-wide track, 200s clip → 2s per pixel.
    double snap(double touchTrackX, double currentValue) => scrubStartValue(
          touchTrackX: touchTrackX,
          currentValue: currentValue,
          effectiveWidth: 100,
          duration: 200,
          grabRadius: 20,
        );

    test('touching the line away from the thumb snaps to that position', () {
      // Thumb is at 0s (x=0); touch at x=75 → 75% → 150s.
      expect(snap(75, 0), 150.0);
    });

    test('grabbing the thumb keeps the current value', () {
      // Thumb at 100s sits at x=50; a touch at x=55 is within grabRadius.
      expect(snap(55, 100), 100.0);
    });

    test('a touch just outside the grab radius snaps', () {
      // Thumb at 100s → x=50; touch at x=71 is >20px away → snaps to 71%.
      expect(snap(71, 100), closeTo(142.0, 1e-9));
    });

    test('touch position is clamped to the track bounds', () {
      expect(snap(-30, 0), 0.0); // before the start
      expect(snap(130, 0), 200.0); // past the end
    });

    test('returns the current value when duration is unknown', () {
      expect(
        scrubStartValue(
          touchTrackX: 40,
          currentValue: 12,
          effectiveWidth: 100,
          duration: 0,
          grabRadius: 20,
        ),
        12.0,
      );
    });
  });
}
