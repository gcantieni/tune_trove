import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Subdirectory under the app documents directory where imported/picked audio
/// files are copied so they survive deletion of the original.
const audioStoreDirName = 'audio_recordings';

/// Returns a filename that does not collide with an existing file in [dir],
/// appending `_2`, `_3`, … before the extension as needed.
String uniqueFilename(Directory dir, String name) {
  final ext = p.extension(name);
  final base = p.basenameWithoutExtension(name);
  var candidate = name;
  var counter = 2;
  while (File(p.join(dir.path, candidate)).existsSync()) {
    candidate = '${base}_$counter$ext';
    counter++;
  }
  return candidate;
}

/// Copies the file at [sourcePath] into the app's audio store, using
/// [displayName] for the destination filename (de-duplicated). Returns the
/// absolute destination path.
Future<String> copyIntoAudioStore(String sourcePath, String displayName) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final destDir = Directory(p.join(docsDir.path, audioStoreDirName));
  await destDir.create(recursive: true);

  final filename = uniqueFilename(destDir, displayName);
  final destFile = await File(sourcePath).copy(p.join(destDir.path, filename));
  return destFile.path;
}
