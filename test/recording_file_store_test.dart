import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tune_trove/feat/recording_list/recording_file_store.dart';

void main() {
  group('uniqueFilename', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('audio_store_test');
    });
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('returns the name unchanged when no collision', () {
      expect(uniqueFilename(dir, 'memo.m4a'), 'memo.m4a');
    });

    test('suffixes _2, _3 on successive collisions', () {
      File(p.join(dir.path, 'memo.m4a')).writeAsStringSync('x');
      expect(uniqueFilename(dir, 'memo.m4a'), 'memo_2.m4a');

      File(p.join(dir.path, 'memo_2.m4a')).writeAsStringSync('x');
      expect(uniqueFilename(dir, 'memo.m4a'), 'memo_3.m4a');
    });
  });
}
