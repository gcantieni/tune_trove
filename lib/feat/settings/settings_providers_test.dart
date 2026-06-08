import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/settings/settings_providers.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/database_provider.dart';

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

  Future<bool?> readInvert() {
    // Keep the autoDispose provider alive while we await its first value.
    final sub = container.listen(invertNotationInDarkModeProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(invertNotationInDarkModeProvider.future);
  }

  test('defaults to true when the setting has never been written', () async {
    expect(await readInvert(), isTrue);
  });

  test("reflects a stored 'false' value", () async {
    await db.appSettingsDao.setValue(kInvertNotationInDarkMode, 'false');
    expect(await readInvert(), isFalse);
  });

  test("reflects a stored 'true' value", () async {
    await db.appSettingsDao.setValue(kInvertNotationInDarkMode, 'true');
    expect(await readInvert(), isTrue);
  });
}
