import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/model/database_provider.dart';

final navScaffoldKey = GlobalKey<ScaffoldState>();

// Branch indices in the StatefulShellRoute (see app_router.dart). The first
// three are the bottom tabs; the last two are the drawer destinations.
const _tunesBranchIndex = 1;
const _firstDrawerBranchIndex = 3; // Settings (3), Content Library (4)

// Pages that render their own bottom-right "add" FAB, on which we shift the
// global play/pause FAB left so the two don't overlap. The list pages have one;
// their detail sub-routes (/tune_list/$id, /recording_list/$id) do not — except
// set detail (/set_list/$id), which does.
bool _hasAddFab(String location) =>
    location == '/tune_list' ||
    location == '/recording_list' ||
    location == '/set_list' ||
    location.startsWith('/set_list/');

/// App shell: a persistent bottom tab bar plus a hamburger drawer for the
/// secondary (Settings / Content Library) destinations, wrapping the
/// [StatefulNavigationShell] that hosts each branch's own navigator.
class NavScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const NavScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final index = navigationShell.currentIndex;
    final onTab = index < _firstDrawerBranchIndex;

    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final showFab = playerState.isPlaying || playerState.isPaused;

    return Scaffold(
      key: navScaffoldKey,
      drawerEnableOpenDragGesture: false,
      body: navigationShell,
      drawer: NavigationDrawer(
        selectedIndex: onTab ? null : index - _firstDrawerBranchIndex,
        onDestinationSelected: (i) {
          navScaffoldKey.currentState?.closeDrawer();
          navigationShell.goBranch(_firstDrawerBranchIndex + i);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text(
              'Tune Trove',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.settings_outlined),
            label: Text('Settings'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.library_books_outlined),
            label: Text('Content Library'),
          ),
        ],
      ),
      bottomNavigationBar: _BottomTabBar(
        selectedIndex: onTab ? index : null,
        onSelected: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
      ),
      // Shift the global play/pause FAB left so it sits beside (not on top
      // of) each page's own bottom-right "add" FAB.
      floatingActionButton: showFab
          ? Padding(
              padding: EdgeInsets.only(right: _hasAddFab(location) ? 72 : 0),
              child: GestureDetector(
                onLongPress: () async {
                  final url = playerState.trackUri;
                  if (url == null) return;
                  final id = await ref
                      .read(databaseProvider)
                      .recordingDao
                      .findIdByUrl(url);
                  if (id == null || !context.mounted) return;
                  context.go('/recording_list/$id');
                },
                child: FloatingActionButton(
                  heroTag: 'global_play_pause',
                  tooltip: playerState.isPlaying ? 'Pause' : 'Resume',
                  onPressed: playerState.isPlaying
                      ? notifier.pause
                      : notifier.resume,
                  child: Icon(
                    playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Persistent bottom navigation across the three primary tabs. When the current
/// location belongs to no tab (Settings / Content Library) the bar is rendered
/// without a selection highlight.
class _BottomTabBar extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _BottomTabBar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(
      selectedIndex: selectedIndex ?? _tunesBranchIndex,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.queue_music),
          label: 'Sets',
        ),
        NavigationDestination(
          icon: Icon(Icons.music_note),
          label: 'Tunes',
        ),
        NavigationDestination(
          icon: Icon(Icons.audio_file_outlined),
          label: 'Recordings',
        ),
      ],
    );
    // On non-tab pages, hide the selection pill so no tab looks active.
    if (selectedIndex == null) {
      return NavigationBarTheme(
        data: NavigationBarTheme.of(
          context,
        ).copyWith(indicatorColor: Colors.transparent),
        child: bar,
      );
    }
    return bar;
  }
}
