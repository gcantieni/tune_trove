# Riverpod Standards

## Provider Types

| Use case | Provider type |
|----------|--------------|
| Reactive DB query | `StreamProvider.autoDispose` |
| One-shot async load | `FutureProvider.autoDispose` |
| Singleton service | `Provider` (no autoDispose) |
| Mutable UI state | `NotifierProvider` |
| Parameterized query | `.family` modifier |

## Naming Conventions

- Providers: `<noun><Noun>Provider` — e.g., `allTunesProvider`, `singleTuneProvider`
- Notifiers: `<Noun>Notifier` — e.g., `TuneFiltersNotifier`
- Use descriptive names that indicate what data is provided, not implementation details.

## Architecture Rules

- `databaseProvider` is the single source of truth for the `AppDatabase` instance.
- All other data providers depend on `databaseProvider` via `ref.watch(databaseProvider)`.
- Providers never import widget code. Widgets import providers, not the other way around.
- Use `ref.watch()` in build methods, `ref.read()` in callbacks and event handlers.

## Testing Providers

- Create a `ProviderContainer` with `databaseProvider` overridden to an in-memory DB.
- Use `container.listen()` to capture emissions.
- Always dispose the container in `tearDown`.
- Allow a small `Future.delayed` for stream debounce when testing reactive providers.
- Providers that depend on `sharedPreferencesProvider` (e.g., anything under the content-source chain) need it overridden in tests. Rather than mocking SharedPreferences, override the derived provider that's actually under test. For example, tests for `filteredTunesProvider` override `activeSourceNamesProvider` directly with a fixed `Set<String>`:

```dart
ProviderContainer(
  overrides: [
    activeSourceNamesProvider.overrideWithValue(const {}),
    allTunesProvider.overrideWith((ref) => Stream.value(tunes)),
  ],
);
```

## Injected Infrastructure

`sharedPreferencesProvider` is a sentinel provider — it throws if not overridden. `main()` resolves `SharedPreferences.getInstance()` before `runApp()` and injects the instance via `ProviderScope.overrides`. Any provider that needs SharedPreferences must sit downstream of this provider in the dependency graph, not call `SharedPreferences.getInstance()` directly.

## Notifiers

- `Notifier` (synchronous) for UI filter/sort state.
- `AsyncNotifier` for state that requires async initialization.
- Keep mutation methods focused — one action per method.
- Use `copyWith` patterns for immutable state updates (see `TuneFilters`).

## Avoid

- Don't use `StateProvider` — prefer `NotifierProvider` for explicit mutations.
- Don't put UI logic (showing dialogs, navigation) inside providers.
- Don't chain too many `.family` modifiers — if a provider needs 3+ params, create a params class.
