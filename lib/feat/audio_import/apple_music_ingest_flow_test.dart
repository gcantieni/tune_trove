import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tune_trove/feat/audio_import/audio_import_controller.dart';
import 'package:tune_trove/feat/audio_import/audio_import_models.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';
import 'package:tune_trove/feat/audio_import/mock_audio_import_service.dart';
import 'package:tune_trove/feat/music_kit/mock_music_kit_service.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';
import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/routing/app_router.dart';

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

  late AppDatabase db;
  late MockAudioImportService importService;
  late MockMusicKitService musicKit;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    importService = MockAudioImportService();
    musicKit = MockMusicKitService();
    // Start on the dependency-light Recorder tab (router is a global singleton).
    router.go('/recorder');
  });

  tearDown(() async {
    await db.close();
    importService.dispose();
    musicKit.dispose();
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      audioImportServiceProvider.overrideWithValue(importService),
      musicKitServiceProvider.overrideWithValue(musicKit),
    ],
    child: const _Harness(),
  );

  Future<void> pumpEmit(WidgetTester tester, SharedAudioFile item) async {
    await tester.runAsync(() async {
      importService.emit(item);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('an Apple Music song link becomes a music-catalog recording', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(RecordingFormWidget), findsNothing);

    await pumpEmit(
      tester,
      const SharedAudioFile(
        url: 'https://music.apple.com/us/album/cold-blow/123?i=789012',
        name: 'shared link',
      ),
    );

    // Navigated to Recordings and opened the prefilled form with the catalog URL
    // and the mock-resolved "Title — Artist" name.
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.textContaining('music-catalog:789012'), findsOneWidget);
    expect(find.textContaining('The Morning Dew'), findsWidgets);
  });

  testWidgets('a non-Apple-Music link falls back to a raw-URL recording', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await pumpEmit(
      tester,
      const SharedAudioFile(url: 'https://example.com/x', name: 'some link'),
    );

    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.textContaining('https://example.com/x'), findsOneWidget);
    expect(find.textContaining('music-catalog:'), findsNothing);
  });

  testWidgets('two rapid link shares open exactly one form (_busy guard)', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      importService.emit(
        const SharedAudioFile(
          url: 'https://music.apple.com/us/song/a/111',
          name: 'a',
        ),
      );
      importService.emit(
        const SharedAudioFile(
          url: 'https://music.apple.com/us/song/b/222',
          name: 'b',
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(RecordingFormWidget), findsOneWidget);
  });
}
