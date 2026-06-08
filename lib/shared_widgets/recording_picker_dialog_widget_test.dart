import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/shared_widgets/recording_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(String name, String url, {String? performers}) {
    return db.recordingDao.insertRecording(
      RecordingsCompanion(
        name: drift.Value(name),
        url: drift.Value(url),
        performers: drift.Value(performers),
        createdAt: drift.Value(DateTime.now()),
      ),
    );
  }

  // Pumps the picker dialog inside a ProviderScope backed by the in-memory db.
  Future<({List<Recording> picked, List<RecordingsCompanion> created})>
  pumpDialog(WidgetTester tester) async {
    final picked = <Recording>[];
    final created = <RecordingsCompanion>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RecordingPickerDialog(
                    title: 'Pick a recording',
                    onPicked: picked.add,
                    onCreateNew: created.add,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (picked: picked, created: created);
  }

  // Enters search text and advances past the 100ms debounce.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  testWidgets('empty query lists all recordings', (tester) async {
    await seed("Cooley's Reel", 'https://ex.com/1');
    await seed('The Butterfly', 'https://ex.com/2');
    await pumpDialog(tester);

    expect(find.text("Cooley's Reel"), findsOneWidget);
    expect(find.text('The Butterfly'), findsOneWidget);
  });

  testWidgets('query filters by name, case-insensitively', (tester) async {
    await seed("Cooley's Reel", 'https://ex.com/1');
    await seed('The Butterfly', 'https://ex.com/2');
    await pumpDialog(tester);

    await search(tester, 'butter');
    expect(find.text('The Butterfly'), findsOneWidget);
    expect(find.text("Cooley's Reel"), findsNothing);
  });

  testWidgets('shows the no-recordings-yet message when library is empty', (
    tester,
  ) async {
    await pumpDialog(tester);
    expect(
      find.textContaining('No recordings yet'),
      findsOneWidget,
    );
  });

  testWidgets('a URL query offers a create-from-URL tile', (tester) async {
    await pumpDialog(tester);
    await search(tester, 'https://example.com/track.mp3');
    expect(find.text('Create new recording'), findsOneWidget);
    // The URL appears both in the search field and the tile subtitle.
    expect(find.text('https://example.com/track.mp3'), findsWidgets);
  });

  testWidgets('a plain-name query offers a create-by-name tile', (
    tester,
  ) async {
    await pumpDialog(tester);
    await search(tester, 'My New Tune');
    expect(find.text('Create recording named "My New Tune"'), findsOneWidget);
  });

  testWidgets('tapping a recording invokes onPicked and closes', (
    tester,
  ) async {
    await seed('The Butterfly', 'https://ex.com/2', performers: 'Planxty');
    final results = await pumpDialog(tester);

    await tester.tap(find.text('The Butterfly'));
    await tester.pumpAndSettle();

    expect(results.picked, hasLength(1));
    expect(results.picked.single.name, 'The Butterfly');
    expect(find.text('Pick a recording'), findsNothing); // dialog popped
  });

  testWidgets('create-from-URL tile switches to the inline create form', (
    tester,
  ) async {
    await pumpDialog(tester);
    await search(tester, 'https://example.com/track.mp3');
    await tester.tap(find.text('Create new recording'));
    await tester.pumpAndSettle();
    expect(find.text('New recording'), findsOneWidget);
  });
}
