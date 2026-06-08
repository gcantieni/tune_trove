import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/recording_list/recording_link_kind.dart';

void main() {
  group('recordingLinkKindOf', () {
    test('file: and app-data: map to file', () {
      expect(recordingLinkKindOf('file:///x.m4a'), RecordingLinkKind.file);
      expect(
        recordingLinkKindOf('app-data:recordings/x.m4a'),
        RecordingLinkKind.file,
      );
    });

    test('apple music, youtube, spotify, generic', () {
      expect(
        recordingLinkKindOf('music-catalog:123'),
        RecordingLinkKind.appleMusic,
      );
      expect(
        recordingLinkKindOf('https://youtu.be/abc'),
        RecordingLinkKind.youtube,
      );
      expect(recordingLinkKindOf('spotify:track:1'), RecordingLinkKind.spotify);
      expect(
        recordingLinkKindOf('https://example.com'),
        RecordingLinkKind.generic,
      );
    });
  });

  group('iconForLinkKind', () {
    test('file uses the audio-file icon', () {
      expect(
        iconForLinkKind(RecordingLinkKind.file),
        Icons.audio_file_outlined,
      );
    });
  });

  group('supportsInAppPlayback', () {
    test('true for file and appleMusic', () {
      expect(supportsInAppPlayback(RecordingLinkKind.file), isTrue);
      expect(supportsInAppPlayback(RecordingLinkKind.appleMusic), isTrue);
    });

    test('false for youtube, spotify, generic', () {
      expect(supportsInAppPlayback(RecordingLinkKind.youtube), isFalse);
      expect(supportsInAppPlayback(RecordingLinkKind.spotify), isFalse);
      expect(supportsInAppPlayback(RecordingLinkKind.generic), isFalse);
    });
  });
}
