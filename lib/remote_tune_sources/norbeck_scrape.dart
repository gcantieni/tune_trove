// One-time script to produce assets/data/norbeck_tunes.json from the Norbeck
// ABC collection ZIP.
//
// Usage:
//   dart lib/remote_tune_sources/norbeck_scrape.dart
//
// Downloads https://www.norbeck.nu/abc/hn202601.zip, unzips it in a temp
// directory, parses all .abc files, and writes assets/data/norbeck_tunes.json.
// Never compiled into the app.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

const _zipUrl = 'https://www.norbeck.nu/abc/hn202601.zip';
const _outPath = 'assets/data/norbeck_tunes.json';

void main() async {
  final client = http.Client();
  try {
    stdout.writeln('Downloading $_zipUrl ...');
    final response = await client.get(Uri.parse(_zipUrl));
    if (response.statusCode != 200) {
      stderr.writeln('Download failed: ${response.statusCode}');
      exit(1);
    }

    final tmpDir = Directory.systemTemp.createTempSync('norbeck_');
    final zipPath = p.join(tmpDir.path, 'hn.zip');
    File(zipPath).writeAsBytesSync(response.bodyBytes);

    stdout.writeln('Unzipping ...');
    final result = await Process.run('unzip', [
      '-q',
      zipPath,
      '-d',
      tmpDir.path,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('unzip failed: ${result.stderr}');
      exit(1);
    }

    final abcFiles = tmpDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.abc'))
        .toList();

    stdout.writeln('Found ${abcFiles.length} ABC files');

    final tunes = <Map<String, dynamic>>[];
    for (final file in abcFiles) {
      tunes.addAll(_parseTunes(file.readAsStringSync()));
    }

    stdout.writeln('Parsed ${tunes.length} tunes');
    File(_outPath).writeAsStringSync(jsonEncode(tunes));
    stdout.writeln('Wrote $_outPath');

    tmpDir.deleteSync(recursive: true);
  } finally {
    client.close();
  }
}

List<Map<String, dynamic>> _parseTunes(String abcContent) {
  final tunes = <Map<String, dynamic>>[];
  final chunks = abcContent.split(RegExp('^X:', multiLine: true));
  for (final chunk in chunks) {
    if (chunk.trim().isEmpty) continue;
    final fullAbc = 'X:$chunk'.trim();
    final name = _field(fullAbc, 'T');
    final type = _field(fullAbc, 'R');
    final key = _field(fullAbc, 'K');
    if (name == null) continue;
    tunes.add({
      'name': name,
      'type': type ?? '',
      'key': key ?? '',
      'abc': fullAbc,
    });
  }
  return tunes;
}

String? _field(String abc, String tag) {
  final match = RegExp('^$tag: *(.+)\$', multiLine: true).firstMatch(abc);
  return match?.group(1)?.trim();
}
