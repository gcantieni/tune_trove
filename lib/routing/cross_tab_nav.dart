import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation helpers for the per-tab stack model ([StatefulShellRoute]).
///
/// Each bottom tab (Sets / Tunes / Recordings) is an independent branch with
/// its own navigator. A link that points *into another tab* (e.g. a recording
/// listed on a tune detail) must switch branches rather than push onto the
/// current one — and we record where we came from so the destination's back
/// arrow can return there ("return to origin"), even though it lives in a
/// different branch.

/// Query-parameter key carrying the origin location for return-to-origin back.
const _fromParam = 'from';

/// Navigates to [location] in its owning tab branch, remembering the current
/// location so [originAwareLeading] on the destination returns here.
///
/// Use for links that cross tabs. Same-tab drill-downs (list → detail) should
/// keep using `context.push`, which stacks within the active branch.
void goCrossTab(BuildContext context, String location) {
  final from = GoRouterState.of(context).uri.toString();
  context.go('$location?$_fromParam=${Uri.encodeQueryComponent(from)}');
}

/// Reads the return-to-origin location from a detail route's state, or `null`
/// when the page was reached normally (within its own tab).
String? returnToOf(GoRouterState state) =>
    state.uri.queryParameters[_fromParam];

/// AppBar `leading` for a detail page that may have been opened from another
/// tab. When [returnTo] is set, the back arrow returns to that origin location
/// (across tabs); otherwise returns `null` so the AppBar falls back to its
/// default pop-within-branch back button.
Widget? originAwareLeading(BuildContext context, String? returnTo) {
  if (returnTo == null) return null;
  return IconButton(
    icon: const BackButtonIcon(),
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.go(returnTo),
  );
}
