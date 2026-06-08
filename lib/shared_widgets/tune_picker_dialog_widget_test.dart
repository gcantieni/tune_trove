import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/remote_tune_sources/remote_tune.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/shared_widgets/tune_picker_dialog.dart';

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

  Future<void> seedTune(String name, {int? tsId, String? source}) {
    return db.tuneDao.insertTune(
      TunesCompanion(
        name: drift.Value(name),
        genre: const drift.Value('irish'),
        tsId: drift.Value(tsId),
        source: drift.Value(source),
        createdAt: drift.Value(DateTime.now()),
      ),
    );
  }

  // Pumps the dialog with a fixed remote-search result (no network) and the
  // given active source names. Returns the collected callback invocations.
  Future<
    ({List<Tune> library, List<TunesCompanion> remote, List<String> created})
  >
  pumpDialog(
    WidgetTester tester, {
    Map<String, List<RemoteTune>> remoteResults = const {},
    Set<String> activeSourceIds = const {},
    String? initialQuery,
  }) async {
    final library = <Tune>[];
    final remote = <TunesCompanion>[];
    final created = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          activeSourceIdsProvider.overrideWithValue(activeSourceIds),
          tuneSearchProvider.overrideWith((ref, query) => remoteResults),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TunePickerDialog(
                    title: 'Pick a tune',
                    initialQuery: initialQuery,
                    onLibraryTune: library.add,
                    onRemoteTune: remote.add,
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
    return (library: library, remote: remote, created: created);
  }

  // Enters search text and advances past the 350ms debounce.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('empty query shows the start-typing prompt', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Start typing to find a tune.'), findsOneWidget);
  });

  testWidgets('initialQuery pre-fills the search and shows matches at once', (
    tester,
  ) async {
    await seedTune("Cooley's Reel");
    // No debounce advance: results should already be visible on first frame.
    await pumpDialog(tester, initialQuery: "Cooley's Reel");

    expect(find.widgetWithText(TextField, "Cooley's Reel"), findsOneWidget);
    expect(find.text('In your library'), findsOneWidget);
    expect(find.text("Cooley's Reel"), findsWidgets);
  });

  testWidgets('matching local tunes appear under the library section', (
    tester,
  ) async {
    await seedTune("Cooley's Reel");
    await pumpDialog(tester);
    await search(tester, 'cooley');

    expect(find.text('In your library'), findsOneWidget);
    expect(find.text("Cooley's Reel"), findsOneWidget);
    expect(find.text('In library'), findsOneWidget);
  });

  testWidgets('remote results appear under a per-source section', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      remoteResults: {
        'thesession.org': const [
          RemoteTune(name: 'The Butterfly', sourceName: 'thesession.org'),
        ],
      },
    );
    await search(tester, 'butterfly');

    expect(find.text('From thesession.org'), findsOneWidget);
    expect(find.text('The Butterfly'), findsOneWidget);
  });

  testWidgets('a thesession result duplicating a local tsId is hidden', (
    tester,
  ) async {
    await seedTune("Cooley's Reel", tsId: 999);
    await pumpDialog(
      tester,
      remoteResults: {
        'thesession.org': const [
          // sourceId 999 matches the local tune's tsId -> dropped.
          RemoteTune(
            name: 'Cooley dupe',
            sourceName: 'thesession.org',
            sourceId: '999',
          ),
          // sourceId 111 is not in the library -> kept.
          RemoteTune(
            name: 'Fresh Remote',
            sourceName: 'thesession.org',
            sourceId: '111',
          ),
        ],
      },
    );
    await search(tester, 'cooley');

    expect(find.text('Fresh Remote'), findsOneWidget);
    expect(find.text('Cooley dupe'), findsNothing);
  });

  testWidgets('settings within a source sort by date ascending', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      remoteResults: {
        'thesession.org': [
          RemoteTune(
            name: 'Setting Newer',
            sourceName: 'thesession.org',
            sourceId: '1',
            settingId: 2,
            date: DateTime(2015, 3, 4),
          ),
          RemoteTune(
            name: 'Setting Older',
            sourceName: 'thesession.org',
            sourceId: '1',
            settingId: 1,
            date: DateTime(2005, 3, 4),
          ),
        ],
      },
    );
    await search(tester, 'setting');

    final olderY = tester.getTopLeft(find.text('Setting Older')).dy;
    final newerY = tester.getTopLeft(find.text('Setting Newer')).dy;
    expect(olderY, lessThan(newerY));
  });

  testWidgets('publishing age and contributor show in the subtitle', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      remoteResults: {
        'thesession.org': [
          RemoteTune(
            name: 'Dated Tune',
            sourceName: 'thesession.org',
            sourceId: '1',
            key: 'Edor',
            date: DateTime(2010, 3, 4),
            contributor: 'Jeremy',
          ),
        ],
      },
    );
    await search(tester, 'dated');

    expect(find.textContaining('years ago'), findsOneWidget);
    expect(find.textContaining('by Jeremy'), findsOneWidget);
  });

  testWidgets('thesession.org section sorts after curated sources', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      remoteResults: {
        'thesession.org': const [
          RemoteTune(name: 'Aggregator Tune', sourceName: 'thesession.org'),
        ],
        'Pete Mac Tunebook': const [
          RemoteTune(name: 'Curated Tune', sourceName: 'Pete Mac Tunebook'),
        ],
      },
    );
    await search(tester, 'tune');

    final curatedY = tester.getTopLeft(find.text('From Pete Mac Tunebook')).dy;
    final aggregatorY = tester.getTopLeft(find.text('From thesession.org')).dy;
    expect(curatedY, lessThan(aggregatorY));
  });

  testWidgets('create-new tile appears with typed text', (tester) async {
    await pumpDialog(tester);
    await search(tester, 'Brand New Tune');
    expect(find.text('Create new tune "Brand New Tune"'), findsOneWidget);
  });

  testWidgets('tapping a library tune fires onLibraryTune and closes', (
    tester,
  ) async {
    await seedTune('The Butterfly');
    final results = await pumpDialog(tester);
    await search(tester, 'butterfly');

    await tester.tap(find.text('The Butterfly'));
    await tester.pumpAndSettle();

    expect(results.library, hasLength(1));
    expect(results.library.single.name, 'The Butterfly');
    expect(find.text('Pick a tune'), findsNothing); // dialog popped
  });

  testWidgets('library tunes from inactive sources are hidden', (tester) async {
    // 'thesession' is a registered source id; with no active sources it
    // is not visible, so the tune is filtered out.
    await seedTune('Hidden Tune', source: 'thesession');
    await pumpDialog(tester);
    await search(tester, 'hidden');

    expect(find.text('Hidden Tune'), findsNothing);
  });
}
