import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tune_trove/feat/abc_render/abc_renderer.dart';
import 'package:tune_trove/feat/audio_import/audio_import_controller.dart';
import 'package:tune_trove/feat/cloudkit_sync/cloudkit_sync_providers.dart';
import 'package:tune_trove/feat/cloudkit_sync/sync_notifier.dart';
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

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<int>? _overwriteSub;

  @override
  void initState() {
    super.initState();
    // Pull the latest from iCloud once on launch. Wait for the notifier's
    // initial availability check to finish first, otherwise its build() future
    // could resolve after syncNow() and clobber the in-progress state.
    Future.microtask(() async {
      await ref.read(syncProvider.future);
      await ref.read(syncProvider.notifier).syncNow();
    });

    // Warn when a last-writer-wins conflict discarded a local edit. Subscribe
    // to the raw stream (not a provider) so repeated same-count events aren't
    // deduped away.
    _overwriteSub = ref
        .read(cloudKitSyncServiceProvider)
        .localOverwrites
        .listen(_showOverwriteWarning);
  }

  @override
  void dispose() {
    _overwriteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enable automatic sync-on-change for the app's lifetime.
    ref.watch(syncStagerProvider);
    // Own the shared-audio import flow at the app root so files shared into the
    // app are absorbed on any tab, not just while Recordings is mounted.
    ref.watch(audioImportControllerProvider);
    ref.listen(syncProvider, (prev, next) {
      _onSyncStateChanged(prev?.value?.phase, next.value);
    });

    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final colorScheme = ColorScheme.fromSeed(
      contrastLevel: 0.75,
      seedColor: const Color(0xFF0C2E1E),
      brightness: brightness,
    );

    return MaterialApp.router(
      title: 'Tune Trove',
      scaffoldMessengerKey: _scaffoldMessengerKey,
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

  void _showOverwriteWarning(int count) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    final message = count <= 1
        ? 'A change you made was replaced by a newer edit from another device.'
        : '$count of your changes were replaced by newer edits from another device.';
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange.shade900,
        duration: const Duration(seconds: 6),
        content: Text(message),
      ),
    );
  }

  void _onSyncStateChanged(SyncPhase? prevPhase, SyncState? next) {
    if (next == null || next.phase == prevPhase) return;
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    switch (next.phase) {
      case SyncPhase.syncing:
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(minutes: 1),
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Text('Syncing from iCloud…'),
              ],
            ),
          ),
        );
      case SyncPhase.success:
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Sync complete'),
          ),
        );
      case SyncPhase.partial:
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(content: Text(next.detail ?? 'Sync completed with issues')),
        );
      case SyncPhase.error:
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('iCloud sync failed')),
        );
      case SyncPhase.idle:
      case SyncPhase.unavailable:
        // Don't nag on launch when not signed in or before the first sync.
        break;
    }
  }
}
