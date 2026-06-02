import 'dart:async';

import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';

/// Minimal in-memory [CloudKitSyncService] for exercising the Dart sync layer
/// (stager, notifier) without the platform channel.
class FakeCloudKitSyncService implements CloudKitSyncService {
  bool available;
  SendResult sendResult;
  FetchedChanges fetched;

  int initializeCalls = 0;
  int sendCalls = 0;
  final List<List<Map<String, dynamic>>> stagedRecords = [];
  final List<List<Map<String, dynamic>>> stagedDeletions = [];

  final _remote = StreamController<void>.broadcast();
  final _overwrites = StreamController<int>.broadcast();

  FakeCloudKitSyncService({
    this.available = true,
    this.sendResult = const SendResult(),
    this.fetched = const FetchedChanges([], []),
  });

  /// Simulate a silent push from another device.
  void emitRemoteChange() => _remote.add(null);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<FetchedChanges> fetchChanges() async => fetched;

  @override
  Future<void> stageRecords(List<Map<String, dynamic>> records) async =>
      stagedRecords.add(records);

  @override
  Future<void> stageDeletions(List<Map<String, dynamic>> deletions) async =>
      stagedDeletions.add(deletions);

  @override
  Future<SendResult> sendChanges() async {
    sendCalls++;
    return sendResult;
  }

  @override
  Stream<void> get remoteChanges => _remote.stream;

  @override
  Stream<int> get localOverwrites => _overwrites.stream;

  @override
  void dispose() {
    _remote.close();
    _overwrites.close();
  }
}
