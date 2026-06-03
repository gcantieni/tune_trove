import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

/// Short git commit the app was built from, injected at build time via
/// `--dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)` (see the Makefile
/// run/build targets). Empty in plain `flutter run`/IDE launches that don't
/// pass the define.
const kGitCommit = String.fromEnvironment('GIT_COMMIT');

/// Build identification string for the Settings footer / bug reports, e.g.
/// `v1.0.24 (24) · a1b2c3d`. Combines the pubspec version + build number
/// (from [PackageInfo]) with [kGitCommit] when available.
final buildInfoProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final base = 'v${info.version} (${info.buildNumber})';
  return kGitCommit.isEmpty ? base : '$base · $kGitCommit';
});
