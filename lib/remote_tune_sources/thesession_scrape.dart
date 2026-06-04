// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// Regenerates `assets/data/thesession_tunes.json` from the official
/// TheSession.org data dump (https://github.com/adactio/TheSession-data).
///
/// Unlike the old per-tune HTML scrape (which kept only one transcription per
/// tune), this preserves **every setting**, so the picker can let the user
/// browse and choose among them, ordered by publishing date.
///
/// Usage:
///   `dart run lib/remote_tune_sources/thesession_scrape.dart <tunes.json>`
///
/// where `<tunes.json>` is the `tunes.json` file from the TheSession-data repo
/// (an array of rows with keys: tune_id, setting_id, name, type, meter, mode,
/// abc, date, username). Defaults to `./tunes.json` if no path is given.
///
/// Output schema (one object per setting), matching `parseStaticJson`:
///   `{"id": <tune_id>, "setting_id": <setting_id>, "name", "type",`
///   `"key": <mode>, "abc", "date": "YYYY-MM-DD", "by": <username>}`
Future<void> main(List<String> args) async {
  final inputPath = args.isNotEmpty ? args.first : 'tunes.json';
  final input = File(inputPath);
  if (!input.existsSync()) {
    stderr.writeln(
      'Input not found: $inputPath\n'
      'Download tunes.json from https://github.com/adactio/TheSession-data',
    );
    exitCode = 1;
    return;
  }

  final rows = (jsonDecode(await input.readAsString()) as List)
      .cast<Map<String, dynamic>>();

  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    final abc = (row['abc'] as String?)?.trim();
    if (abc == null || abc.isEmpty) continue;
    out.add({
      'id': _toInt(row['tune_id']),
      'setting_id': _toInt(row['setting_id']),
      'name': row['name'],
      'type': row['type'],
      'key': row['mode'],
      'abc': abc,
      'date': _isoDate(row['date'] as String?),
      'by': row['username'],
    });
  }

  final outFile = File('assets/data/thesession_tunes.json');
  await outFile.writeAsString(jsonEncode(out));
  print('Wrote ${out.length} settings to ${outFile.path}');
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v == null) return null;
  return int.tryParse('$v'.trim());
}

/// Normalizes "2001-08-10 00:00:00" (or similar) to "2001-08-10". Returns null
/// when the date can't be parsed.
String? _isoDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (parsed == null) {
    // Fall back to a leading YYYY-MM-DD substring if present.
    final m = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(raw.trim());
    return m?.group(0);
  }
  final mm = parsed.month.toString().padLeft(2, '0');
  final dd = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$mm-$dd';
}
