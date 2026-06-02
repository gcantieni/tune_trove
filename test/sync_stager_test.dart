import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_outbound_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_reconciliation_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_stager.dart';
import 'package:tune_trove/model/database.dart';

import 'support/fake_cloudkit_sync_service.dart';

void main() {
  late AppDatabase db;
  late FakeCloudKitSyncService fake;
  late SyncOutboundService outbound;
  late SyncStager stager;

  setUp(() async {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = FakeCloudKitSyncService(
      sendResult: const SendResult(failedCount: 2, failures: ['a: x', 'b: y']),
    );
    outbound = SyncOutboundService(
      db,
      fake,
      SyncReconciliationService(db),
      prefs,
    );
  });

  tearDown(() async {
    stager.dispose();
    await db.close();
  });

  test('the periodic sweep runs a push and reports its result', () async {
    final results = <SendResult>[];
    final got = Completer<void>();
    stager = SyncStager(
      db,
      fake,
      outbound,
      sweepInterval: const Duration(milliseconds: 50),
      onResult: (r) {
        results.add(r);
        if (!got.isCompleted) got.complete();
      },
    );
    stager.start();

    await got.future.timeout(const Duration(seconds: 2));
    expect(fake.sendCalls, greaterThan(0));
    expect(results.first.failedCount, 2);
    expect(results.first.failures, ['a: x', 'b: y']);
  });

  test('a remote change triggers a pull whose result is reported', () async {
    final results = <SendResult>[];
    final got = Completer<void>();
    stager = SyncStager(
      db,
      fake,
      outbound,
      // Long sweep so only the remote-change path fires during the test.
      sweepInterval: const Duration(minutes: 5),
      onResult: (r) {
        results.add(r);
        if (!got.isCompleted) got.complete();
      },
    );
    stager.start();

    fake.emitRemoteChange();

    await got.future.timeout(const Duration(seconds: 2));
    expect(fake.sendCalls, greaterThan(0));
    expect(results.first.failedCount, 2);
  });
}
