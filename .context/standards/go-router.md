# GoRouter Standards

## Route Structure

- All routes defined in `lib/routing/app_router.dart`.
- Use a `ShellRoute` for the persistent navigation scaffold.
- Nest detail routes under their parent list routes (e.g., `/tune_list/:id`).

## Naming

- Every route has a `name` matching its path segment (e.g., `name: 'tune_detail'`).
- Use `context.goNamed('tune_detail', pathParameters: {'id': '$id'})` for navigation.
- Never hardcode path strings in widgets — always use named routes.

## Parameters

- Pass entity IDs as path parameters, not query parameters or objects.
- Parse path parameters at the route level, not in child widgets.
- Detail pages accept the parsed ID in their constructor.

## Transitions

- Custom transitions live in the router file, not in page widgets.
- Use `CustomTransitionPage` with `pageBuilder` for animated transitions.
- Transition direction is determined by nav index ordering.

## Guards and Redirects

- Add redirects in the `GoRouter` constructor if auth or onboarding gates are needed.
- Keep redirect logic pure — no side effects.

## Dialogs Inside GoRouter Pages

Always pop dialogs using the **dialog's own context**, not the outer page context.

```dart
// WRONG — pops GoRouter's root navigator, which has no dialog on its stack
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),  // crashes
        ...
      ),
    ],
  ),
);

// CORRECT — pops the dialog's inner navigator
showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog(
    actions: [
      TextButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        ...
      ),
    ],
  ),
);
```

`showDialog` pushes onto a nested `Navigator` inside Flutter's dialog layer. `Navigator.of(outerContext)` walks up to GoRouter's root navigator, which has no dialog on its stack — popping it triggers GoRouter's assertion `'currentConfiguration.isNotEmpty'`.
