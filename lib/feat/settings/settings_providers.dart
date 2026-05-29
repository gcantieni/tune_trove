import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/model/database_provider.dart';

/// Setting key controlling whether ABC sheet music is inverted (white-on-black)
/// to match the theme in dark mode. Stored in the synced `app_settings` table.
const kInvertNotationInDarkMode = 'invertNotationInDarkMode';

/// Whether ABC notation should be inverted to match the theme in dark mode.
///
/// Defaults to `true` (the historical behaviour) when the setting has never
/// been written, so existing users keep theme-matched white-on-black notation.
final invertNotationInDarkModeProvider = StreamProvider.autoDispose<bool>((
  ref,
) {
  return ref
      .watch(databaseProvider)
      .appSettingsDao
      .watchValue(kInvertNotationInDarkMode)
      .map((value) => value == null || value == 'true');
});
