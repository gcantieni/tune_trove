import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/model/database_provider.dart';

final navScaffoldKey = GlobalKey<ScaffoldState>();

// Primary destinations shown in the persistent bottom navigation bar, in
// display order (Sets, Tunes, Recordings).
const _tabRoutes = [
  '/set_list',
  '/tune_list',
  '/recording_list',
];

// Secondary destinations reached via the top-left hamburger drawer. Pushed (not
// switched to) so they keep the bottom bar and get a back button.
const _drawerRoutes = [
  '/settings',
  '/content_library',
];

/// Index of the active bottom tab, or `null` when the current location belongs
/// to no tab (Settings / Content Library). Detail sub-routes map to their tab.
int? _tabIndex(String location) {
  for (int i = 0; i < _tabRoutes.length; i++) {
    final r = _tabRoutes[i];
    if (location == r || location.startsWith('$r/')) return i;
  }
  return null;
}

/// Index of the active drawer destination, or `null` when not on one.
int? _drawerIndex(String location) {
  for (int i = 0; i < _drawerRoutes.length; i++) {
    final r = _drawerRoutes[i];
    if (location == r || location.startsWith('$r/')) return i;
  }
  return null;
}

// Pages that render their own bottom-right "add" FAB, on which we shift the
// global play/pause FAB left so the two don't overlap. The list pages have one;
// their detail sub-routes (/tune_list/$id, /recording_list/$id) do not — except
// set detail (/set_list/$id), which does.
bool _hasAddFab(String location) =>
    location == '/tune_list' ||
    location == '/recording_list' ||
    location == '/set_list' ||
    location.startsWith('/set_list/');

class NavScaffold extends ConsumerWidget {
  final Widget child;

  const NavScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final tabIndex = _tabIndex(location);

    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final showFab = playerState.isPlaying || playerState.isPaused;

    return Scaffold(
      key: navScaffoldKey,
      body: child,
      drawer: NavigationDrawer(
        selectedIndex: _drawerIndex(location),
        onDestinationSelected: (index) {
          navScaffoldKey.currentState?.closeDrawer();
          context.push(_drawerRoutes[index]);
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
      bottomNavigationBar: _BottomTabBar(selectedIndex: tabIndex),
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

  const _BottomTabBar({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final bar = NavigationBar(
      selectedIndex: selectedIndex ?? 0,
      onDestinationSelected: (index) => context.go(_tabRoutes[index]),
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
