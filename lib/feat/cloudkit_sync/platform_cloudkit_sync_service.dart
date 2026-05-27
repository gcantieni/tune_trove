import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

const _methodChannel = MethodChannel('com.gcantieni.tuneTrove/cloudkit_sync');
const _eventChannel = EventChannel(
  'com.gcantieni.tuneTrove/cloudkit_sync_state',
);

class PlatformCloudKitSyncService implements CloudKitSyncService {
  StreamSubscription<dynamic>? _sub;
  final _statusController = StreamController<SyncStatusEvent>.broadcast();
  final _remoteChangesController = StreamController<void>.broadcast();
  final _localOverwriteController = StreamController<int>.broadcast();

  PlatformCloudKitSyncService() {
    _sub = _eventChannel.receiveBroadcastStream().listen((dynamic raw) {
      if (raw is! Map) return;
      final map = raw.cast<String, dynamic>();
      switch (map['type']) {
        case 'status':
          _statusController.add(
            SyncStatusEvent(
              map['status'] as String? ?? 'idle',
              message: map['message'] as String?,
            ),
          );
        case 'remoteChange':
          _remoteChangesController.add(null);
        case 'localOverwritten':
          _localOverwriteController.add((map['count'] as int?) ?? 1);
      }
    }, onError: _statusController.addError);
  }

  @override
  Future<bool> isAvailable() async {
    final result = await _methodChannel.invokeMethod<bool>('isAvailable');
    return result ?? false;
  }

  @override
  Future<void> initialize() => _methodChannel.invokeMethod<void>('initialize');

  @override
  Future<FetchedChanges> fetchChanges() async {
    final raw = await _methodChannel.invokeMethod<dynamic>('fetchChanges');
    if (raw is! Map) return const FetchedChanges([], []);
    final map = raw.cast<String, dynamic>();

    final upserts = <SyncUpsertEvent>[];
    for (final u in (map['upserts'] as List? ?? const [])) {
      final um = (u as Map).cast<String, dynamic>();
      upserts.add(
        SyncUpsertEvent(
          um['recordType'] as String,
          (um['fields'] as Map).cast<String, dynamic>(),
        ),
      );
    }

    final deletions = <SyncDeleteEvent>[];
    for (final d in (map['deletions'] as List? ?? const [])) {
      final dm = (d as Map).cast<String, dynamic>();
      deletions.add(
        SyncDeleteEvent(dm['recordType'] as String, dm['cloudId'] as String),
      );
    }

    return FetchedChanges(upserts, deletions);
  }

  @override
  Future<void> stageRecords(List<Map<String, dynamic>> records) =>
      _methodChannel.invokeMethod<void>('stageRecords', records);

  @override
  Future<void> stageDeletions(List<Map<String, dynamic>> deletions) =>
      _methodChannel.invokeMethod<void>('stageDeletions', deletions);

  @override
  Future<SendResult> sendChanges() async {
    final raw = await _methodChannel.invokeMethod<dynamic>('sendChanges');
    if (raw is! Map) return const SendResult();
    final m = raw.cast<String, dynamic>();
    return SendResult(
      saved: (m['saved'] as int?) ?? 0,
      failedCount: (m['failedCount'] as int?) ?? 0,
      failures: ((m['failures'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  @override
  Stream<SyncStatusEvent> get statusEvents => _statusController.stream;

  @override
  Stream<void> get remoteChanges => _remoteChangesController.stream;

  @override
  Stream<int> get localOverwrites => _localOverwriteController.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _statusController.close();
    _remoteChangesController.close();
    _localOverwriteController.close();
  }
}
