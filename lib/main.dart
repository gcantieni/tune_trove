import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';
import 'package:tune_trove/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final colorScheme = ColorScheme.fromSeed(
      contrastLevel: 0.75,
      seedColor: const Color(0xFF0C2E1E),
      brightness: brightness,
    );

    return MaterialApp.router(
      title: 'Tune Trove',
      theme: ThemeData(
        colorScheme: colorScheme,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: colorScheme.secondary,
          unselectedItemColor: colorScheme.secondaryContainer,
        ),
      ),
      routerConfig: router,
      builder: (context, child) => Stack(
        children: [child ?? const SizedBox.shrink(), const AbcRendererAnchor()],
      ),
    );
  }
}
