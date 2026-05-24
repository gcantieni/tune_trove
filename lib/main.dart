import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:tune_trove/routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
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
