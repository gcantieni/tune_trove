# Flutter Standards

## Project Principles

- **Test-Driven Development** — Write a failing test before writing implementation code. No exceptions for unit-testable logic.
- **Offline-first** — All data lives locally in SQLite via Drift. Network features are supplementary.
- **Feature isolation** — Each feature module under `lib/feat/` is self-contained. Cross-feature communication happens through providers.
- **Minimal abstraction** — Don't introduce layers or indirection without a concrete need. Three similar lines are better than a premature abstraction.

## Widget Guidelines

- Prefer `StatelessWidget` or `ConsumerWidget`. Use `StatefulWidget` only when managing focus nodes, animation controllers, or text editing controllers.
- Keep `build()` methods short. Extract sub-trees into private methods or separate widgets when a build method exceeds ~50 lines.
- Use `const` constructors wherever possible.
- Never perform side effects in `build()`. Use `ref.listen()` for reacting to state changes.

## State Management (Riverpod)

- All shared state flows through Riverpod providers.
- Use `autoDispose` on providers unless the data must outlive all listeners.
- Prefer `StreamProvider` for reactive database queries.
- Use `Notifier` / `AsyncNotifier` for mutable state with defined mutation methods.
- Override `databaseProvider` in tests — never construct a real database in test code.

## Code Style

- Follow `package:lint/strict.yaml` rules.
- No `print()` calls in production code.
- Use named parameters for constructors with more than two arguments.
- Enum values use `camelCase`.
- File names use `snake_case`.
- One public class per file (private helpers are fine in the same file).

## Error Handling

- Let Drift handle constraint violations — don't duplicate validation in Dart when the DB enforces it.
- Use `AsyncValue.guard()` for provider error propagation.
- Surface errors to the user via SnackBar or inline messages, never silently swallow them.

## Navigation

- All routes are defined in `lib/routing/app_router.dart` using GoRouter.
- Use named routes (`context.goNamed(...)`) rather than path strings.
- Pass IDs as path parameters, not whole objects.

## CocoaPods Policy

**This project has fully migrated away from CocoaPods. Do not add it back.**

The iOS target uses Swift Package Manager exclusively — there is no `Podfile` in `ios/`. This was an intentional migration to eliminate CocoaPods as a build dependency, improve CI reliability, and reduce toolchain complexity.

### Rules

- **Never add a Flutter package that pulls in a CocoaPods dependency.** Before adding any pub.dev package, check whether its iOS implementation uses a `.podspec` file or `s.dependency` declarations. If it does, find an alternative.
- **Never run `pod install` or create a `Podfile`.** If Xcode or Flutter tooling suggests running pod install, investigate why rather than complying — the fix is usually a package swap, not re-introducing CocoaPods.
- **Prefer packages that use Swift Package Manager (SPM) or pure-Dart implementations** for their native layer.

### How to vet a package before adding it

1. Check the package's `ios/` directory on pub.dev or GitHub for a `.podspec` file.
2. If a `.podspec` is present, look for an SPM alternative (`Package.swift`) — some packages support both.
3. Search pub.dev for packages that solve the same problem without native iOS code at all (pure Dart is always preferred).
4. If no CocoaPods-free alternative exists, raise it as a blocker rather than adding the dependency.

### Known safe packages (SPM or pure-Dart on iOS)

| Package | iOS native layer |
| --- | --- |
| `webview_flutter` | SPM (`webview_flutter_wkwebview`) |
| `just_audio` | SPM |
| `file_picker` | SPM |
| `path_provider` | SPM |
| `url_launcher` | SPM |
| `flutter_svg` | Pure Dart |
| `drift` / `drift_flutter` | Pure Dart (uses `sqlite3_flutter_libs`) |
| `go_router` | Pure Dart |
| `flutter_riverpod` | Pure Dart |
| `http` / `html` | Pure Dart |

### Historical context

`flutter_inappwebview` was previously used for ABC notation rendering and was replaced with `webview_flutter` as part of this migration. `flutter_inappwebview` uses CocoaPods; `webview_flutter` does not. Any future WebView work must continue using `webview_flutter`.
