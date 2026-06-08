import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tune_trove/feat/audio_import/audio_import_controller.dart';
import 'package:tune_trove/feat/audio_import/audio_import_service.dart';
import 'package:tune_trove/feat/audio_import/mock_audio_import_service.dart';
import 'package:tune_trove/feat/music_kit/mock_music_kit_service.dart';
import 'package:tune_trove/feat/music_kit/music_kit_service.dart';
import 'package:tune_trove/feat/recording_list/recording_form_widget.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/routing/app_router.dart';

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
  String clipboardText = '';

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    importService = MockAudioImportService();
    musicKit = MockMusicKitService();
    router.go('/recording_list');
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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

  testWidgets('Add-from-link ingests an Apple Music URL from the clipboard', (
    tester,
  ) async {
    clipboardText = 'https://music.apple.com/us/album/cold-blow/123?i=789012';
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add from Apple Music link'));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(RecordingFormWidget), findsOneWidget);
    expect(find.textContaining('music-catalog:789012'), findsOneWidget);
  });

  testWidgets('Add-from-link shows a hint when the clipboard has no AM link', (
    tester,
  ) async {
    clipboardText = 'https://example.com/not-music';
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Add from Apple Music link'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pump();

    expect(find.byType(RecordingFormWidget), findsNothing);
    expect(find.text('Copy an Apple Music link first.'), findsOneWidget);
  });
}
