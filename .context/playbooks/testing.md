# Testing Playbook

## Philosophy: Test-Driven Development

All unit-testable logic MUST follow the Red-Green-Refactor cycle:

1. **Red** — Write a failing test that defines the expected behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up while keeping tests green

Never write implementation code without a corresponding failing test first.

## Running Tests

```bash
flutter test lib                                  # all tests
flutter test lib/model/providers/provider_test.dart  # single file
flutter test lib --name "singleTuneProvider"      # by name
```

There is **no `test/` directory** — tests are co-located in `lib/` next to the
code they exercise (a `*_test.dart` beside its subject). `flutter test` with no
path defaults to `test/` and would find nothing, so always pass `lib` (the
Makefile `test`/`coverage` targets already do).

## Test Structure

Each test sits next to its subject, e.g.:

- `lib/model/providers/provider_test.dart` — Riverpod provider integration tests
- `lib/util/abc_metadata_test.dart` — pure unit tests beside `abc_metadata.dart`
- `lib/model/database_test.dart` — database operation tests
- `lib/model/database_migration_test.dart` (+ `lib/model/migration_schemas/`) —
  schema migration verification tests

## Writing Database Tests

Use an in-memory database to avoid filesystem dependencies:

```dart
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

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
```

## Writing Provider Tests

Use `ProviderContainer` with overrides — never depend on a real database or widget tree for provider logic tests:

```dart
final container = ProviderContainer(
  overrides: [databaseProvider.overrideWithValue(db)],
);

final sub = container.listen<AsyncValue<List<Tune>>>(
  allTunesProvider,
  (previous, next) => emitted.add(next),
  fireImmediately: true,
);
```

## What to Test

- DAOs: insert, update, delete, query operations
- Providers: stream emissions, state transitions, error handling
- Data parsing: external data format conversion (e.g., TheSession JSON)
- Filters/sort logic: pure functions in isolation
- Domain logic: any business rules not tied to UI

## What NOT to Unit Test

- Widget layout (use integration/golden tests for that)
- Generated code (`.g.dart` files)
- Simple pass-through constructors
