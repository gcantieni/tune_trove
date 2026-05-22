import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tune_trove/feat/audio_player/audio_player_notifier.dart';
import 'package:tune_trove/model/database_provider.dart';

class NavScaffold extends ConsumerWidget {
  final Widget child;

  const NavScaffold({required this.child, super.key});

  static const List<String> _bottomNavigationRoutes = [
    '/set_list',
    '/tune_list',
    '/recording_list',
    '/recorder',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _bottomNavigationRoutes.indexWhere(
      (r) => location.startsWith(r),
    );

    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final showFab = playerState.isPlaying || playerState.isPaused;

    return Scaffold(
      body: child,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0
            ? 3 // recorder should be the "quick draw" for the app
            : currentIndex,
        onTap: (index) {
          if (_bottomNavigationRoutes[index] != location) {
            context.go(_bottomNavigationRoutes[index]); // skip home
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: "Sets"),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Tunes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.audio_file_outlined),
            label: 'Recordings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
        ],
      ),
    );
  }
}
