# Build Playbook

## Prerequisites

- Flutter SDK ≥ 3.8.1
- Dart SDK (bundled with Flutter)

## Install Dependencies

```bash
flutter pub get
```

## Code Generation (Drift)

After modifying table definitions or DAOs:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Run the App

```bash
flutter run                  # default device
flutter run -d chrome        # web
flutter run -d macos         # macOS desktop
flutter run -d ios            # iOS simulator
```

## Build for Release

```bash
flutter build ios
flutter build macos
flutter build apk
flutter build web
```

## Analyze

```bash
flutter analyze
```

Uses `package:lint/strict.yaml` as the base analysis ruleset.

## Database Schema Migrations

When adding or modifying a table:

1. Update the table class in `lib/model/tables/`
2. Increment `schemaVersion` in `lib/model/database.dart`
3. Add the migration step in the `stepByStep()` block
4. Run code generation
5. Export the new schema for tests:
   ```bash
   dart run drift_dev schema dump lib/model/database.dart drift_schemas/
   dart run drift_dev schema generate drift_schemas/ lib/model/migration_schemas/
   ```
6. Update migration tests in `lib/model/database_migration_test.dart`
