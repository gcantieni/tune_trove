import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/tune_dao.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';

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
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('singleTuneProvider', () async {
    final tuneDao = TuneDao(db);

    final id = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value('test tune'),
        createdAt: drift.Value(DateTime.now()),
        genre: const drift.Value('irish'),
      ),
    );

    final emitted = <Tune?>[];
    final firstValue = Completer<void>();
    final secondValue = Completer<void>();

    final sub = container.listen<AsyncValue<Tune?>>(
      singleTuneProvider(id),
      (_, next) {
        if (!next.hasValue) return;
        emitted.add(next.value);
        if (!firstValue.isCompleted) {
          firstValue.complete();
        } else if (!secondValue.isCompleted) {
          secondValue.complete();
        }
      },
      fireImmediately: true,
    );

    await firstValue.future;

    await tuneDao.updateTune(
      TunesCompanion(id: drift.Value(id), genre: const drift.Value('contra')),
    );

    await secondValue.future;
    sub.close();

    expect(emitted[0]?.genre, 'irish');
    expect(emitted.last?.genre, 'contra');
  });

  test('allTunesProvider', () async {
    final tuneDao = TuneDao(db);

    final history = <List<Tune>>[];
    final firstEmit = Completer<void>();
    final thirdEmit = Completer<void>();

    final sub = container.listen<AsyncValue<List<Tune>>>(
      allTunesProvider,
      (_, next) {
        if (!next.hasValue) return;
        history.add(next.value!);
        if (!firstEmit.isCompleted) firstEmit.complete();
        if (history.length >= 3 && !thirdEmit.isCompleted) thirdEmit.complete();
      },
      fireImmediately: true,
    );

    await firstEmit.future;

    final id1 = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value('test tune'),
        createdAt: drift.Value(DateTime.now()),
        genre: const drift.Value('irish'),
      ),
    );

    final id2 = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value('test tune'),
        createdAt: drift.Value(DateTime.now()),
        genre: const drift.Value('irish'),
      ),
    );

    await thirdEmit.future;
    sub.close();

    expect(history[0], isEmpty);
    expect(history[1].length, equals(1));
    expect(history[1][0].id, equals(id1));
    expect(history[2].length, equals(2));
    expect(history[2][0].id, equals(id1));
    expect(history[2][1].id, equals(id2));
  });
}
