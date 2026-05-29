import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_import/audio_import_models.dart';

void main() {
  group('SharedAudioFile.fromMap', () {
    test('parses path and name', () {
      final f = SharedAudioFile.fromMap({
        'path': '/tmp/New Recording 7.m4a',
        'name': 'New Recording 7.m4a',
      });
      expect(f, isNotNull);
      expect(f!.path, '/tmp/New Recording 7.m4a');
      expect(f.name, 'New Recording 7.m4a');
    });

    test('derives name from path when missing', () {
      final f = SharedAudioFile.fromMap({'path': '/tmp/memo.m4a'});
      expect(f!.name, 'memo.m4a');
    });

    test('returns null when path missing or empty', () {
      expect(SharedAudioFile.fromMap({'name': 'x'}), isNull);
      expect(SharedAudioFile.fromMap({'path': ''}), isNull);
    });
  });
}
