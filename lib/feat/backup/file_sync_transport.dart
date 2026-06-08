// dart imports
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

// package imports
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/recording_list/recording_file_store.dart';
import 'package:tune_trove/feat/sync_core/sync_record_codec.dart';
import 'package:tune_trove/feat/sync_core/sync_transport.dart';
import 'package:tune_trove/model/database.dart';

/// The record types written to a file backup. Mirrors CloudKit exactly — every
/// synced type, AppSettings included — so the ZIP is a faithful snapshot and the
/// external data sources (iCloud, file, future cloud drives) behave uniformly.
const backupRecordTypes = allSyncRecordTypes;

/// Thrown when a backup archive can't be applied to this install.
class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => 'BackupFormatException: $message';
}

/// A [SyncTransport] backed by a ZIP archive of canonical records plus an
/// `audio/` folder of the user's local recording files.
///
/// Archive layout:
/// ```text
/// manifest.json   { appVersion, schemaVersion, exportedAt, recordTypes, counts }
/// records.json    [ <canonical record>, … ]   (backupRecordTypes only)
/// audio/<cloudId>__<filename>                  (one per local recording)
/// ```
///
/// [buildArchive]/[readArchive] are the testable core; [push]/[pull] adapt them
/// to the share sheet and an in-memory source for the [SyncTransport] contract.
class FileSyncTransport implements SyncTransport {
  final AppDatabase _db;

  /// Bytes of a backup archive to read on [pull]. Set for the import direction.
  final List<int>? _source;

  // Named params can't be private initializing formals, so assign in the body.
  // ignore: prefer_initializing_formals
  FileSyncTransport(this._db, {List<int>? source}) : _source = source;

  @override
  String get id => 'file';

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Builds the backup ZIP for [records], bundling the audio file of every
  /// local-file recording. Returns the encoded archive bytes.
  Future<List<int>> buildArchive(
    List<Map<String, dynamic>> records, {
    String appVersion = '',
  }) async {
    final archive = Archive();

    final recordsBytes = utf8.encode(jsonEncode(records));
    archive.addFile(
      ArchiveFile('records.json', recordsBytes.length, recordsBytes),
    );

    final counts = <String, int>{};
    for (final r in records) {
      final type = r['recordType'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }

    for (final r in records) {
      if (r['recordType'] != recordingRecordType) continue;
      final url = r['url'] as String?;
      final cloudId = r['cloudId'] as String?;
      if (url == null || cloudId == null) continue;
      final path = await _localAudioPath(url);
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final entryName = 'audio/${cloudId}__${p.basename(path)}';
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }

    final manifest = utf8.encode(
      jsonEncode({
        'appVersion': appVersion,
        'schemaVersion': _db.schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'recordTypes': counts.keys.toList(),
        'counts': counts,
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw BackupFormatException('Failed to encode backup archive.');
    }
    return encoded;
  }

  /// Builds the archive and hands it to the user. Satisfies [SyncTransport.push];
  /// the cancellable result is available via [deliver].
  @override
  Future<void> push(List<Map<String, dynamic>> records) async {
    await deliver(await buildArchive(records));
  }

  // Note: callers presenting the share sheet on iOS should use [deliver] with a
  // sharePositionOrigin; [push] omits it (fine for desktop / the generic seam).

  /// Presents the backup [bytes] for the user to keep. On desktop (macOS et al.)
  /// this is a native **Save** panel — the share sheet there has no "Save to
  /// Files". On iOS/Android it's the share sheet (whose "Save to Files" covers
  /// the same need). Returns false if the user cancelled the save panel.
  ///
  /// [sharePositionOrigin] anchors the share popover; iOS *requires* a non-zero
  /// rect (else `sharePositionOrigin: argument must be set`). Pass the source
  /// widget's global rect.
  Future<bool> deliver(List<int> bytes, {Rect? sharePositionOrigin}) async {
    final fileName = 'tunecatcher-backup-${_timestamp()}.zip';

    if (Platform.isIOS || Platform.isAndroid) {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Tune Catcher backup',
        sharePositionOrigin: sharePositionOrigin,
      );
      return true;
    }

    final savePath = await FilePicker.saveFile(
      dialogTitle: 'Save Tune Catcher backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: Uint8List.fromList(bytes),
    );
    if (savePath == null) return false; // user cancelled
    // saveFile returns the chosen path; on desktop it does not write the bytes
    // itself, so persist them here (harmless if a platform already did).
    await File(savePath).writeAsBytes(bytes);
    return true;
  }

  String _timestamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp('[:.]'), '-')
      .replaceAll('T', '-')
      .substring(0, 17);

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Parses a backup ZIP: materializes each bundled audio file into the local
  /// audio store and rewrites the owning recording's `url` to the new local
  /// path, then returns the records as a [FetchedChanges] for reconciliation.
  Future<FetchedChanges> readArchive(List<int> bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BackupFormatException('Not a valid ZIP archive.');
    }

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile != null) {
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
      final fileSchema = manifest['schemaVersion'] as int?;
      if (fileSchema != null && fileSchema > _db.schemaVersion) {
        throw BackupFormatException(
          'This backup was made by a newer app version '
          '(schema v$fileSchema > v${_db.schemaVersion}). Update the app first.',
        );
      }
    }

    final recordsFile = archive.findFile('records.json');
    if (recordsFile == null) {
      throw BackupFormatException('Backup is missing records.json.');
    }
    final decoded =
        jsonDecode(utf8.decode(recordsFile.content as List<int>)) as List;
    final records = [
      for (final r in decoded) Map<String, dynamic>.from(r as Map),
    ];

    // Index audio entries by the cloudId prefix encoded in their filename.
    final audioByCloudId = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (!f.name.startsWith('audio/')) continue;
      final base = p.basename(f.name);
      final sep = base.indexOf('__');
      if (sep <= 0) continue;
      audioByCloudId[base.substring(0, sep)] = f;
    }

    for (final r in records) {
      if (r['recordType'] != recordingRecordType) continue;
      final cloudId = r['cloudId'] as String?;
      if (cloudId == null) continue;
      final entry = audioByCloudId[cloudId];
      if (entry == null) continue;

      // If this recording already exists locally with a present audio file
      // (e.g. re-importing the same backup), keep it — don't duplicate the
      // file on disk.
      final existing = await _db.recordingDao.getByCloudId(cloudId);
      if (existing != null) {
        final path = await _localAudioPath(existing.url);
        if (path != null && File(path).existsSync()) {
          r['url'] = existing.url;
          continue;
        }
      }

      final originalName = p.basename(entry.name).substring(cloudId.length + 2);
      final newPath = await _materializeAudio(
        entry.content as List<int>,
        originalName,
      );
      r['url'] = 'file://$newPath';
    }

    return recordsToFetchedChanges(records);
  }

  /// Reads the archive supplied at construction. Satisfies [SyncTransport.pull].
  @override
  Future<FetchedChanges> pull() {
    final source = _source;
    if (source == null) {
      throw StateError('FileSyncTransport.pull() requires a source archive.');
    }
    return readArchive(source);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves a recording url to a local filesystem path, or null for external
  /// urls (https/spotify/music-catalog/…) that carry no bundled audio.
  Future<String?> _localAudioPath(String url) async {
    if (url.startsWith('file://')) return url.substring('file://'.length);
    if (url.startsWith('app-data:')) {
      final rel = url.substring('app-data:'.length);
      final docs = await getApplicationDocumentsDirectory();
      return p.join(docs.path, rel);
    }
    return null;
  }

  /// Writes [bytes] into the app's audio store under a de-duplicated name based
  /// on [displayName], reusing [copyIntoAudioStore]. Returns the absolute path.
  Future<String> _materializeAudio(List<int> bytes, String displayName) async {
    final tmp = await getTemporaryDirectory();
    final tmpFile = File(p.join(tmp.path, 'import_${p.basename(displayName)}'));
    await tmpFile.writeAsBytes(bytes);
    final dest = await copyIntoAudioStore(tmpFile.path, displayName);
    try {
      await tmpFile.delete();
    } catch (_) {}
    return dest;
  }
}
