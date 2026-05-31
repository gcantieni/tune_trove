import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:tune_trove/feat/audio_import/audio_import_controller.dart';
import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';
import 'package:tune_trove/feat/audio_import/mock_audio_import_service.dart';
import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/routing/app_router.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

/// App-root harness: the `AudioImportController` is watched here (as in
/// `main.dart`) so the import flow is owned globally, and the real `router` is
/// driven so a shared file surfaces on whatever tab is active.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(audioImportControllerProvider);
    return MaterialApp.router(routerConfig: router);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocs;
  late Directory sourceDir;
  late AppDatabase db;
  late MockAudioImportService importService;

  setUp(() {
    tempDocs = Directory.systemTemp.createTempSync('vm_docs');
    sourceDir = Directory.systemTemp.createTempSync('vm_src');
    PathProviderPlatform.instance = _FakePathProvider(tempDocs.path);
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    importService = MockAudioImportService();
    // The router is a global singleton that retains its location between tests;
    // reset to a known, dependency-light tab (Recorder) so each test starts
    // somewhere other than Recordings without needing the Tunes tab's provider
    // graph (shared prefs / content sources).
    router.go('/recorder');
  });

  tearDown(() async {
    await db.close();
    importService.dispose();
    if (tempDocs.existsSync()) tempDocs.deleteSync(recursive: true);
    if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      audioImportServiceProvider.overrideWithValue(importService),
    ],
    child: const _Harness(),
  );

  testWidgets('re-checks for queued shared imports when the app resumes', (
    tester,
  ) async {
    final src = File(p.join(sourceDir.path, 'Shared from extension.m4a'))
      ..writeAsBytesSync([0, 1, 2, 3]);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Nothing at launch.
    expect(find.byType(RecordingFormWidget), findsNothing);

    // A Share Extension drops a file in the App Group container while the app is
    // backgrounded; on resume the app must pick it up.
    importService.enqueueInitial(
      SharedAudioFile(path: src.path, name: 'Shared from extension.m4a'),
    );

    await tester.runAsync(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.textContaining('file://'), findsOneWidget);

    final copied = Directory(p.join(tempDocs.path, 'audio_recordings'))
        .listSync()
        .whereType<File>()
        .toList();
    expect(copied, hasLength(1));
    expect(p.basename(copied.first.path), 'Shared from extension.m4a');
  });

  testWidgets('imports a file shared while on a non-Recordings tab', (
    tester,
  ) async {
    final src = File(p.join(sourceDir.path, 'On another tab.m4a'))
      ..writeAsBytesSync([4, 5, 6, 7]);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // We're on the Recorder tab, not Recordings.
    expect(find.text('Record'), findsOneWidget);
    expect(find.byType(RecordingFormWidget), findsNothing);

    // A file arrives via the live stream (share sheet / drained scheme) while a
    // different tab is active. The root controller must still import it.
    await tester.runAsync(() async {
      importService.emit(
        SharedAudioFile(path: src.path, name: 'On another tab.m4a'),
      );
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    // Navigated to Recordings and opened the prefilled form.
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.textContaining('file://'), findsOneWidget);

    final copied = Directory(p.join(tempDocs.path, 'audio_recordings'))
        .listSync()
        .whereType<File>()
        .toList();
    expect(copied, hasLength(1));
    expect(p.basename(copied.first.path), 'On another tab.m4a');
  });
}
