import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

const _methodChannel = MethodChannel('com.gcantieni.tuneTrove/cloudkit_sync');
const _eventChannel = EventChannel('com.gcantieni.tuneTrove/cloudkit_sync_state');

class PlatformCloudKitSyncService implements CloudKitSyncService {
  StreamSubscription<dynamic>? _sub;
  final _eventsController = StreamController<SyncEvent>.broadcast();

  PlatformCloudKitSyncService() {
    _sub = _eventChannel.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final map = raw.cast<String, dynamic>();
        final type = map['type'] as String?;
        switch (type) {
          case 'status':
            _eventsController.add(
              SyncStatusEvent(
                map['status'] as String? ?? 'idle',
                message: map['message'] as String?,
              ),
            );
          case 'upsert':
            _eventsController.add(
              SyncUpsertEvent(
                map['recordType'] as String,
                (map['fields'] as Map).cast<String, dynamic>(),
              ),
            );
          case 'delete':
            _eventsController.add(
              SyncDeleteEvent(
                map['recordType'] as String,
                map['cloudId'] as String,
              ),
            );
        }
      },
      onError: _eventsController.addError,
    );
  }

  @override
  Future<bool> isAvailable() async {
    final result = await _methodChannel.invokeMethod<bool>('isAvailable');
    return result ?? false;
  }

  @override
  Future<void> startSync() =>
      _methodChannel.invokeMethod<void>('startSync');

  @override
  Future<void> pushChanges(List<Map<String, dynamic>> records) =>
      _methodChannel.invokeMethod<void>('pushChanges', records);

  @override
  Future<void> subscribeToChanges() =>
      _methodChannel.invokeMethod<void>('subscribeToChanges');

  @override
  Stream<SyncEvent> get syncEvents => _eventsController.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _eventsController.close();
  }
}
