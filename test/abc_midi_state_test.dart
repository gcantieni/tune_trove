import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/abc_midi/abc_midi_state.dart';

void main() {
  group('AbcMidiState.isActive', () {
    test('defaults to idle and inactive', () {
      const s = AbcMidiState();
      expect(s.status, AbcMidiStatus.idle);
      expect(s.message, isNull);
      expect(s.isActive, isFalse);
    });

    test('is active while loading', () {
      expect(const AbcMidiState(status: AbcMidiStatus.loading).isActive, isTrue);
    });

    test('is active while playing', () {
      expect(const AbcMidiState(status: AbcMidiStatus.playing).isActive, isTrue);
    });

    test('is inactive when idle or in error', () {
      expect(const AbcMidiState(status: AbcMidiStatus.idle).isActive, isFalse);
      expect(
        const AbcMidiState(status: AbcMidiStatus.error, message: 'boom')
            .isActive,
        isFalse,
      );
    });
  });
}
