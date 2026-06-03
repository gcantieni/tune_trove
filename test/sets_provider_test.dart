import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/sets_provider.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ProviderContainer makeContainer({Set<String> active = const {}}) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activeSourceNamesProvider.overrideWithValue(active),
      ],
    );
  }


  Future<int> seedTune(String name, {String? from}) => db.tuneDao.insertTune(
        TunesCompanion(
          name: drift.Value(name),
          from: drift.Value(from),
          genre: const drift.Value('irish'),
          createdAt: drift.Value(DateTime(2024)),
        ),
      );

  test('allSetsProvider streams sets ordered by position', () async {
    await db.setDao.insertSet(
      TuneSetsCompanion(
        name: const drift.Value('First'),
        createdAt: drift.Value(DateTime(2024)),
      ),
    );
    container = makeContainer();
    // Keep a listener alive so the autoDispose provider doesn't tear down
    // mid-read.
    container.listen(allSetsProvider, (_, _) {});
    final sets = await container.read(allSetsProvider.future);
    expect(sets.single.name, 'First');
  });

  test('setTunesProvider streams every linked tune', () async {
    final setId = await db.setDao.insertSet(
      TuneSetsCompanion(
        name: const drift.Value('Set'),
        createdAt: drift.Value(DateTime(2024)),
      ),
    );
    final t1 = await seedTune('Open Tune');
    final t2 = await seedTune('Gated Tune', from: 'thesession.org');
    await db.setTuneDao.addTuneToSet(setId, t1);
    await db.setTuneDao.addTuneToSet(setId, t2);

    container = makeContainer();
    container.listen(setTunesProvider(setId), (_, _) {});
    final entries = await container.read(setTunesProvider(setId).future);
    expect(entries, hasLength(2));
  });

  test('visibleSetTunesProvider hides tunes from inactive sources', () async {
    final setId = await db.setDao.insertSet(
      TuneSetsCompanion(
        name: const drift.Value('Set'),
        createdAt: drift.Value(DateTime(2024)),
      ),
    );
    final open = await seedTune('Open Tune'); // from == null -> always visible
    final gated = await seedTune('Gated Tune', from: 'thesession.org');
    await db.setTuneDao.addTuneToSet(setId, open);
    await db.setTuneDao.addTuneToSet(setId, gated);

    // No active sources: the gated (registered-source) tune is filtered out.
    container = makeContainer();
    container.listen(visibleSetTunesProvider(setId), (_, _) {});
    final visible =
        await container.read(visibleSetTunesProvider(setId).future);
    expect(visible.map((e) => e.tune.name), ['Open Tune']);

    // With thesession.org active, both are visible.
    final container2 = makeContainer(active: {'thesession.org'});
    addTearDown(container2.dispose);
    container2.listen(visibleSetTunesProvider(setId), (_, _) {});
    final visible2 =
        await container2.read(visibleSetTunesProvider(setId).future);
    expect(visible2, hasLength(2));
  });
}
