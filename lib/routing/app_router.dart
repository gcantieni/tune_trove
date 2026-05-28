import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/content_library/content_library_page.dart';
import 'package:tune_trove/feat/content_library/source_ranking_page.dart';
import 'package:tune_trove/feat/recorder/recorder_page.dart';
import 'package:tune_trove/feat/recording_list/recording_detail_page.dart';
import 'package:tune_trove/feat/recording_list/recording_list_page.dart';
import 'package:tune_trove/feat/set_list/set_detail_page.dart';
import 'package:tune_trove/feat/set_list/set_list_page.dart';
import 'package:tune_trove/feat/settings/settings_page.dart';
import 'package:tune_trove/feat/tune_list/tune_detail_page.dart';
import 'package:tune_trove/feat/tune_list/tune_list_page.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

const _navOrder = [
  '/set_list',
  '/tune_list',
  '/recording_list',
  '/recorder',
  '/settings',
  '/content_library',
];
int _previousNavIndex = 3; // recorder is the initial location

CustomTransitionPage<void> _directionalPage({
  required String path,
  required Widget child,
}) {
  final newIndex = _navOrder.indexOf(path);
  final fromRight = newIndex >= _previousNavIndex;
  _previousNavIndex = newIndex;
  final begin = Offset(fromRight ? 1 : -1, 0);
  return CustomTransitionPage<void>(
    key: ValueKey(path),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

final GoRouter router = GoRouter(
  initialLocation: '/recorder', // recording should be the app's "quick draw"
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return NavScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/set_list',
          name: 'set_list',
          pageBuilder: (context, state) =>
              _directionalPage(path: '/set_list', child: SetListPage()),
          routes: [
            GoRoute(
              path: ':id',
              name: 'set_detail',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return SetDetailPage(setId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/tune_list',
          name: 'tune_list',
          pageBuilder: (context, state) =>
              _directionalPage(path: '/tune_list', child: TuneListPage()),
          routes: [
            GoRoute(
              path: ':id',
              name: 'tune_detail',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return TuneDetailPage(tuneId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/recording_list',
          name: 'recording_list',
          pageBuilder: (context, state) => _directionalPage(
            path: '/recording_list',
            child: RecordingListPage(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              name: 'recording_detail',
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return RecordingDetailPage(recordingId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/recorder',
          name: 'recorder',
          pageBuilder: (context, state) =>
              _directionalPage(path: '/recorder', child: RecorderPage()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) =>
              _directionalPage(path: '/settings', child: SettingsPage()),
        ),
        GoRoute(
          path: '/content_library',
          name: 'content_library',
          pageBuilder: (context, state) => _directionalPage(
            path: '/content_library',
            child: const ContentLibraryPage(),
          ),
          routes: [
            GoRoute(
              path: 'search_order',
              name: 'source_ranking',
              builder: (context, state) => const SourceRankingPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
