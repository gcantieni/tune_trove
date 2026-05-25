import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

const _methodChannel = MethodChannel('com.gcantieni.tuneTrove/cloudkit_sync');
const _eventChannel = EventChannel('com.gcantieni.tuneTrove/cloudkit_sync_state');

class PlatformCloudKitSyncService implements CloudKitSyncService {
  StreamSubscription<dynamic>? _sub;
  final _statusController = StreamController<SyncStatusEvent>.broadcast();

  PlatformCloudKitSyncService() {
    _sub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final map = raw.cast<String, dynamic>();
        if (map['type'] == 'status') {
          _statusController.add(
            SyncStatusEvent(
              map['status'] as String? ?? 'idle',
              message: map['message'] as String?,
            ),
          );
        }
      },
      onError: _statusController.addError,
    );
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
  Future<void> sendChanges() => _methodChannel.invokeMethod<void>('sendChanges');

  @override
  Stream<SyncStatusEvent> get statusEvents => _statusController.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _statusController.close();
  }
}
