import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/model/accessors/tune_dao.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/tables/tunes.dart';

void main() {
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

  // Unit Tests
  test('tuneDao.insertTune', () async {
    final tuneDao = TuneDao(db);

    const name = 'test tune';
    const genre = 'irish';
    const status = TuneStatus.inSet;
    const key = "G minor";
    const type = TuneType.jig;
    const from = "The Burren";

    final id = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value(name),
        createdAt: drift.Value(DateTime.now()),
        modifiedAt: drift.Value(DateTime.now()),
        genre: const drift.Value(genre),
        status: const drift.Value(status),
        key: const drift.Value(key),
        type: const drift.Value(type),
        from: const drift.Value(from),
      ),
    );

    final tune = await tuneDao.getTune(id);

    expect(tune != null, true);
    expect(tune?.name, name);
    expect(tune?.genre, genre);
    expect(tune?.createdAt.isBefore(DateTime.now()), true);

    expect(tune?.status, status);
    expect(tune?.key, key);
    expect(tune?.type, type);
  });

  test('tuneDao.deleteTune removes the tune', () async {
    final tuneDao = TuneDao(db);

    final id = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value('To Be Deleted'),
        createdAt: drift.Value(DateTime.now()),
      ),
    );

    expect(await tuneDao.getTune(id), isNotNull);

    await tuneDao.deleteTune(id);

    expect(await tuneDao.getTune(id), isNull);
  });

  test('tuneDao.watchTune', () async {
    final tuneDao = TuneDao(db);

    const name = 'test tune';
    const genre = 'irish';
    final createdAt = DateTime.now();

    // added during update
    const status = TuneStatus.inSet;
    const key = "G minor";
    const type = TuneType.jig;

    final id = await tuneDao.insertTune(
      TunesCompanion(
        name: const drift.Value(name),
        createdAt: drift.Value(createdAt),
        genre: const drift.Value(genre),
      ),
    );

    final tuneStream = tuneDao.watchTune(id); // to reactively read later

    // read from stream
    expectLater(
      tuneStream,
      emitsInOrder([
        isA<Tune>().having((t) => t.genre, 'genre', genre),
        isA<Tune>()
            .having((t) => t.genre, 'genre', 'contra')
            .having((t) => t.status, 'status', status)
            .having((t) => t.key, 'key', key)
            .having((t) => t.type, 'type', type),
      ]),
    );

    // make an update
    await tuneDao.updateTune(
      TunesCompanion(
        id: drift.Value(id),
        genre: const drift.Value('contra'),
        status: const drift.Value(status),
        key: const drift.Value(key),
        type: const drift.Value(type),
      ),
    );
  });
}
