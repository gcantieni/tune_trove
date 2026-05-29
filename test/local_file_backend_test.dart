import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/audio_player/local_file_backend.dart';

void main() {
  group('pathFromTrackUri', () {
    test('strips file:// scheme', () {
      expect(pathFromTrackUri('file:///tmp/a.m4a'), '/tmp/a.m4a');
    });

    test('strips app-data: scheme', () {
      expect(pathFromTrackUri('app-data:recordings/a.m4a'), 'recordings/a.m4a');
    });

    test('passes through unrecognized values unchanged', () {
      expect(pathFromTrackUri('/already/a/path.m4a'), '/already/a/path.m4a');
    });
  });
}
