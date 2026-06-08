import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/fake_cloudkit_sync_service.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';

void main() {
  late FakeCloudKitSyncService fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeCloudKitSyncService();
    container = ProviderContainer(
      overrides: [cloudKitSyncServiceProvider.overrideWithValue(fake)],
    );
  });

  tearDown(() => container.dispose());

  Future<SyncNotifier> readyNotifier() async {
    await container.read(syncProvider.future); // resolve build() -> idle
    return container.read(syncProvider.notifier);
  }

  SyncState current() => container.read(syncProvider).value!;

  test('reportBackgroundResult surfaces failures as a partial state', () async {
    final notifier = await readyNotifier();
    expect(current().phase, SyncPhase.idle);

    notifier.reportBackgroundResult(
      const SendResult(
        saved: 1,
        failedCount: 2,
        failures: ['a: boom', 'b: bad'],
      ),
    );

    final s = current();
    expect(s.phase, SyncPhase.partial);
    expect(s.failedCount, 2);
    expect(s.failures, ['a: boom', 'b: bad']);
    expect(s.detail, "2 items couldn't upload");
    expect(s.lastSyncedAt, isNotNull);
  });

  test(
    'a clean background result does not snackbar-flip idle to success',
    () async {
      final notifier = await readyNotifier();

      notifier.reportBackgroundResult(const SendResult(saved: 3));

      final s = current();
      // Phase stays idle (no launch-style "Sync complete" pop), but the
      // timestamp is refreshed so the tile reflects recent activity.
      expect(s.phase, SyncPhase.idle);
      expect(s.failedCount, 0);
      expect(s.lastSyncedAt, isNotNull);
    },
  );

  test('a clean background result clears a prior partial problem', () async {
    final notifier = await readyNotifier();
    notifier.reportBackgroundResult(
      const SendResult(failedCount: 1, failures: ['x: nope']),
    );
    expect(current().phase, SyncPhase.partial);

    notifier.reportBackgroundResult(const SendResult(saved: 1));

    final s = current();
    expect(s.phase, SyncPhase.success);
    expect(s.failedCount, 0);
    expect(s.failures, isEmpty);
    expect(s.detail, isNull);
  });
}
