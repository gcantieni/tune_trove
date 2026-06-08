// dart imports
import 'dart:ui' show Rect;

// package imports
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tune_trove/feat/backup/file_sync_transport.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';
import 'package:tune_trove/feat/sync_core/sync_record_codec.dart';
import 'package:tune_trove/model/database_provider.dart';

enum BackupPhase { idle, exporting, importing, success, error }

class BackupState {
  final BackupPhase phase;

  /// Human-readable result or error detail.
  final String? message;

  const BackupState({this.phase = BackupPhase.idle, this.message});

  bool get isBusy =>
      phase == BackupPhase.exporting || phase == BackupPhase.importing;
}

/// Drives the file backup export/import, surfacing progress for the Settings
/// tiles. Both directions go through the shared canonical record format: export
/// uses [serializeAll]; import reconciles via [SyncReconciliationService] so the
/// merge/dedupe is identical to CloudKit's.
class BackupNotifier extends AsyncNotifier<BackupState> {
  @override
  Future<BackupState> build() async => const BackupState();

  /// Serializes the library and hands a ZIP to the share sheet (iOS/Android) or
  /// a native Save panel (desktop). Audio files for local recordings are bundled
  /// in. [sharePositionOrigin] is the source widget's global rect, required by
  /// iOS to anchor the share popover.
  Future<void> exportBackup({Rect? sharePositionOrigin}) async {
    if ((state.value ?? const BackupState()).isBusy) return;
    state = const AsyncData(BackupState(phase: BackupPhase.exporting));
    try {
      final db = ref.read(databaseProvider);
      final records = await serializeAll(db, recordTypes: backupRecordTypes);
      final appVersion = await _appVersion();
      final transport = FileSyncTransport(db);
      final bytes = await transport.buildArchive(records, appVersion: appVersion);
      final saved = await transport.deliver(
        bytes,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (!saved) {
        state = const AsyncData(BackupState()); // user cancelled — no snackbar
        return;
      }
      final n = records.length;
      state = AsyncData(
        BackupState(
          phase: BackupPhase.success,
          message: 'Exported $n record${n == 1 ? '' : 's'} (v$appVersion).',
        ),
      );
    } catch (e) {
      state = AsyncData(
        BackupState(phase: BackupPhase.error, message: e.toString()),
      );
    }
  }

  /// Prompts for a backup ZIP and merges it into the database. Idempotent:
  /// re-importing the same file adds nothing.
  Future<void> importBackup() async {
    if ((state.value ?? const BackupState()).isBusy) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    final files = picked?.files ?? const [];
    final bytes = files.isEmpty ? null : files.first.bytes;
    if (bytes == null) return; // user cancelled

    state = const AsyncData(BackupState(phase: BackupPhase.importing));
    try {
      final db = ref.read(databaseProvider);
      final changes = await FileSyncTransport(db, source: bytes).pull();
      await ref.read(syncReconciliationProvider).applyFetched(changes);
      state = AsyncData(
        BackupState(
          phase: BackupPhase.success,
          message: _importSummary(changes.upserts.length),
        ),
      );
    } catch (e) {
      state = AsyncData(
        BackupState(phase: BackupPhase.error, message: e.toString()),
      );
    }
  }

  String _importSummary(int count) =>
      'Merged $count record${count == 1 ? '' : 's'} '
      '(existing items were kept; duplicates skipped). '
      'Use Sync Now to push the restored library to iCloud.';

  Future<String> _appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return '?';
    }
  }
}

final backupProvider = AsyncNotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);
