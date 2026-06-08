import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:tune_trove/feat/content_library/content_library_page.dart';
import 'package:tune_trove/feat/content_library/source_ranking_page.dart';
import 'package:tune_trove/feat/recording_list/recording_detail_page.dart';
import 'package:tune_trove/feat/recording_list/recording_list_page.dart';
import 'package:tune_trove/feat/set_list/set_detail_page.dart';
import 'package:tune_trove/feat/set_list/set_list_page.dart';
import 'package:tune_trove/feat/settings/settings_page.dart';
import 'package:tune_trove/feat/tune_list/tune_detail_page.dart';
import 'package:tune_trove/feat/tune_list/tune_list_page.dart';
import 'package:tune_trove/routing/cross_tab_nav.dart';
import 'package:tune_trove/routing/nav_scaffold.dart';

/// Where the app navigates on launch (`/` redirects here). Configurable from
/// Settings via the "Default Page" dropdown and set from persisted prefs in
/// `main()` before the first navigation; defaults to the Tunes tab.
String _defaultStartLocation = '/tune_list';

/// Updates the launch destination. Called from `main()` at startup and from the
/// Settings "Default Page" dropdown (takes effect on next launch).
void setDefaultStartLocation(String location) {
  _defaultStartLocation = location;
}

/// Root navigator key. Lets non-widget owners (e.g. [AudioImportController])
/// surface app-wide UI — like the prefilled add-recording dialog on a shared
/// file — from any tab, via `rootNavigatorKey.currentContext`.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// The five branches behind [StatefulShellRoute]: the three bottom tabs (Sets,
/// Tunes, Recordings — indices 0-2), then Settings and Content Library
/// (indices 3-4), which the hamburger drawer switches to. Each branch keeps its
/// own navigator + history, so switching tabs preserves where you were.
final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) =>
      state.matchedLocation == '/' ? _defaultStartLocation : null,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          NavScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/set_list',
              name: 'set_list',
              builder: (context, state) => SetListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'set_detail',
                  builder: (context, state) => SetDetailPage(
                    setId: int.parse(state.pathParameters['id']!),
                    returnTo: returnToOf(state),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tune_list',
              name: 'tune_list',
              builder: (context, state) => TuneListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'tune_detail',
                  builder: (context, state) => TuneDetailPage(
                    tuneId: int.parse(state.pathParameters['id']!),
                    returnTo: returnToOf(state),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recording_list',
              name: 'recording_list',
              builder: (context, state) => const RecordingListPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'recording_detail',
                  builder: (context, state) => RecordingDetailPage(
                    recordingId: int.parse(state.pathParameters['id']!),
                    returnTo: returnToOf(state),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => SettingsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/content_library',
              name: 'content_library',
              builder: (context, state) => const ContentLibraryPage(),
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
    ),
  ],
);
