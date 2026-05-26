import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/model/database_provider.dart';

final navScaffoldKey = GlobalKey<ScaffoldState>();

const _navRoutes = [
  '/recorder',
  '/set_list',
  '/tune_list',
  '/recording_list',
  '/settings',
  '/content_library',
];

int _drawerIndex(String location) {
  for (int i = 0; i < _navRoutes.length; i++) {
    final r = _navRoutes[i];
    if (location == r || location.startsWith('$r/')) return i;
  }
  return 0;
}

class NavScaffold extends ConsumerWidget {
  final Widget child;

  const NavScaffold({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();

    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final showFab = playerState.isPlaying || playerState.isPaused;

    return Scaffold(
      key: navScaffoldKey,
      body: child,
      drawer: NavigationDrawer(
        selectedIndex: _drawerIndex(location),
        onDestinationSelected: (index) {
          context.go(_navRoutes[index]);
          navScaffoldKey.currentState?.closeDrawer();
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
            icon: Icon(Icons.mic),
            label: Text('Record'),
          ),
          const Divider(indent: 28, endIndent: 28, height: 1),
          const NavigationDrawerDestination(
            icon: Icon(Icons.queue_music),
            label: Text('Sets'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.music_note),
            label: Text('Tunes'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.audio_file_outlined),
            label: Text('Recordings'),
          ),
          const Divider(indent: 28, endIndent: 28, height: 1),
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
      floatingActionButton: showFab
          ? GestureDetector(
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
            )
          : null,
    );
  }
}
