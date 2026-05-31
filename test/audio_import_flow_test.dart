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

/// App-root harness: the import flow is owned by `AudioImportController`
/// (watched here, as in `main.dart`), driving the real `router`.
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
    // The router is a global singleton retaining its location between tests;
    // start on the dependency-light Recorder tab.
    router.go('/recorder');
  });

  tearDown(() async {
    await db.close();
    importService.dispose();
    if (tempDocs.existsSync()) tempDocs.deleteSync(recursive: true);
    if (sourceDir.existsSync()) sourceDir.deleteSync(recursive: true);
  });

  testWidgets('importing an audio file opens the form prefilled with a file:// '
      'URL and copies the file into the audio store', (tester) async {
    final src = File(p.join(sourceDir.path, 'Session clip.m4a'))
      ..writeAsBytesSync([0, 1, 2, 3]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          audioImportServiceProvider.overrideWithValue(importService),
        ],
        child: const _Harness(),
      ),
    );
    await tester.pumpAndSettle();

    // The handler copies the file with real dart:io, whose continuations only
    // make progress inside runAsync; interleave real delays with pumps so the
    // copy completes and the resulting dialog gets built.
    await tester.runAsync(() async {
      importService.emit(
        SharedAudioFile(path: src.path, name: p.basename(src.path)),
      );
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.text('Session clip'), findsWidgets); // name field
    expect(find.textContaining('file://'), findsOneWidget); // url field

    final copied = Directory(p.join(tempDocs.path, 'audio_recordings'))
        .listSync()
        .whereType<File>()
        .toList();
    expect(copied, hasLength(1));
    expect(p.basename(copied.first.path), 'Session clip.m4a');
  });
}
