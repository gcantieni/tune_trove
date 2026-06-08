import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';

void main() {
  group('normalizePickerKey', () {
    test('converts TheSession mode suffixes to picker form', () {
      expect(normalizePickerKey('Ador'), 'ADor');
      expect(normalizePickerKey('Amaj'), 'A');
      expect(normalizePickerKey('Amin'), 'Am');
      expect(normalizePickerKey('Gmix'), 'GMix');
      expect(normalizePickerKey('Bphr'), 'BPhr');
      expect(normalizePickerKey('Clyd'), 'CLyd');
      expect(normalizePickerKey('Eloc'), 'ELoc');
    });

    test('leaves already-normalized keys unchanged', () {
      expect(normalizePickerKey('ADor'), 'ADor');
      expect(normalizePickerKey('Am'), 'Am');
      expect(normalizePickerKey('GMix'), 'GMix');
    });

    test('handles sharps and flats', () {
      expect(normalizePickerKey('F#'), 'F#');
      expect(normalizePickerKey('Bb'), 'Bb');
      expect(normalizePickerKey('F#min'), 'F#m');
      expect(normalizePickerKey('BbDor'), 'BbDor');
    });

    test('a leading b after the root is always a flat, even before a '
        'lowercase mode suffix', () {
      // No mode suffix begins with 'b', so TheSession's lowercase forms are
      // unambiguous: the 'b' is the flat accidental.
      expect(normalizePickerKey('Bbmaj'), 'Bb');
      expect(normalizePickerKey('Bbmin'), 'Bbm');
      expect(normalizePickerKey('Bbdor'), 'BbDor');
      expect(normalizePickerKey('Ebmix'), 'EbMix');
    });

    test('uppercases the root letter', () {
      expect(normalizePickerKey('ador'), 'ADor');
    });

    test('returns strings shorter than 2 chars unchanged', () {
      expect(normalizePickerKey('A'), 'A');
      expect(normalizePickerKey(''), '');
    });
  });

  group('buildPickerKey', () {
    test('assembles letter + accidental + mode suffix', () {
      expect(buildPickerKey(0, 1, 0), 'A'); // A natural Major
      expect(buildPickerKey(1, 2, 0), 'Bb'); // B flat Major
      expect(buildPickerKey(0, 0, 1), 'A#Dor'); // A sharp Dorian
      expect(buildPickerKey(3, 1, 5), 'Dm'); // D natural Minor
      expect(buildPickerKey(6, 1, 4), 'GMix'); // G natural Mixolydian
    });
  });

  group('parsePickerKey', () {
    test('empty string falls back to D natural Major', () {
      expect(parsePickerKey(''), (3, 1, 0));
    });

    test('unknown root letter falls back to the D index', () {
      // 'Zm' keeps the minor mode but the letter index resolves to D (3).
      expect(parsePickerKey('Zm'), (3, 1, 5));
    });

    test('parses accidentals and modes', () {
      expect(parsePickerKey('A'), (0, 1, 0));
      expect(parsePickerKey('Bb'), (1, 2, 0));
      expect(parsePickerKey('A#Dor'), (0, 0, 1));
      expect(parsePickerKey('GMix'), (6, 1, 4));
    });

    test('accepts TheSession format', () {
      expect(parsePickerKey('Ador'), (0, 1, 1));
      expect(parsePickerKey('Amin'), (0, 1, 5));
    });

    test('round-trips with buildPickerKey', () {
      for (final key in [
        'A',
        'Bb',
        'F#',
        'ADor',
        'GMix',
        'Dm',
        'C#Phr',
        'Bbm', // B-flat minor
      ]) {
        final parsed = parsePickerKey(key);
        expect(
          buildPickerKey(parsed.$1, parsed.$2, parsed.$3),
          key,
          reason: 'round-trip for $key',
        );
      }
    });
  });
}
