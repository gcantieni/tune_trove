import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/tune_list/tune_filters.dart';
import 'package:tune_trove/model/database.dart';
import 'package:tune_trove/model/providers/tunes_provider.dart';
import 'package:tune_trove/model/tables/tunes.dart';
import 'package:tune_trove/remote_tune_sources/tune_source_providers.dart';

Tune _tune({
  required int id,
  required String name,
  TuneType? type,
  String? key,
  required DateTime createdAt,
  DateTime? modifiedAt,
}) {
  return Tune(
    id: id,
    name: name,
    key: key,
    type: type,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );
}

ProviderContainer _container(List<Tune> tunes) {
  return ProviderContainer(
    overrides: [
      // No confirmed sources in tests; tunes with null `from` are always visible.
      activeSourceNamesProvider.overrideWithValue(const {}),
      allTunesProvider.overrideWith((ref) => Stream.value(tunes)),
    ],
  );
}

// Listens to filteredTunesProvider and returns the first AsyncData emission.
// Keeps the provider alive (autoDispose) until data arrives.
Future<List<Tune>> _awaitFilteredTunes(ProviderContainer container) {
  final completer = Completer<List<Tune>>();
  ProviderSubscription<AsyncValue<List<Tune>>>? sub;
  sub = container.listen<AsyncValue<List<Tune>>>(
    filteredTunesProvider,
    (_, next) {
      if (!completer.isCompleted) next.whenData(completer.complete);
    },
    fireImmediately: true,
  );
  return completer.future.whenComplete(() => sub?.close());
}

// Waits for allTunesProvider to have data, then reads availableKeysProvider
// while the underlying stream is still alive.
Future<List<String>> _awaitAvailableKeys(ProviderContainer container) async {
  final completer = Completer<void>();
  ProviderSubscription<AsyncValue<List<Tune>>>? sub;
  sub = container.listen<AsyncValue<List<Tune>>>(
    allTunesProvider,
    (_, next) {
      if (!completer.isCompleted) next.whenData((_) => completer.complete());
    },
    fireImmediately: true,
  );
  await completer.future;
  final keys = container.read(availableKeysProvider);
  sub.close();
  return keys;
}

void main() {
  test('isActive is false for default filters', () {
    expect(const TuneFilters().isActive, isFalse);
  });

  test('isActive is true when type is set', () {
    final filters = const TuneFilters().copyWith(type: TuneType.reel);
    expect(filters.isActive, isTrue);
  });

  test('filteredTunesProvider filters by type', () async {
    final tunes = [
      _tune(id: 1, name: "Cooley's", type: TuneType.reel, createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Lark in the Morning', type: TuneType.jig, createdAt: DateTime(2024, 1, 2)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setType(TuneType.reel);

    final list = await _awaitFilteredTunes(container);
    expect(list, hasLength(1));
    expect(list.first.type, TuneType.reel);
  });

  test('filteredTunesProvider filters by key', () async {
    final tunes = [
      _tune(id: 1, name: "Cooley's", key: 'Em', type: TuneType.reel, createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Lark in the Morning', key: 'D', type: TuneType.jig, createdAt: DateTime(2024, 1, 2)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setKey('Em');

    final list = await _awaitFilteredTunes(container);
    expect(list, hasLength(1));
    expect(list.first.key, 'Em');
  });

  test('filteredTunesProvider matches curly apostrophe against straight apostrophe', () async {
    final tunes = [
      _tune(id: 1, name: "Cooley's", type: TuneType.reel, createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Lark in the Morning', type: TuneType.jig, createdAt: DateTime(2024, 1, 2)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    // U+2019 right single quotation mark (curly apostrophe) — common on iOS/macOS
    container.read(tuneFiltersProvider.notifier).setNameQuery('cooley’s');

    final list = await _awaitFilteredTunes(container);
    expect(list, hasLength(1));
    expect(list.first.name, "Cooley's");
  });

  test('filteredTunesProvider filters by name case-insensitively', () async {
    final tunes = [
      _tune(id: 1, name: "Cooley's", type: TuneType.reel, createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Lark in the Morning', type: TuneType.jig, createdAt: DateTime(2024, 1, 2)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setNameQuery('cooley');

    final list = await _awaitFilteredTunes(container);
    expect(list, hasLength(1));
    expect(list.first.name, "Cooley's");
  });

  test('filteredTunesProvider sorts nameAZ', () async {
    final tunes = [
      _tune(id: 1, name: 'Zebra Jig', createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Apple Reel', createdAt: DateTime(2024, 1, 2)),
      _tune(id: 3, name: 'Mango Hornpipe', createdAt: DateTime(2024, 1, 3)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setSort(TuneSort.nameAZ);

    final names = (await _awaitFilteredTunes(container)).map((t) => t.name).toList();
    expect(names, ['Apple Reel', 'Mango Hornpipe', 'Zebra Jig']);
  });

  test('filteredTunesProvider sorts nameZA', () async {
    final tunes = [
      _tune(id: 1, name: 'Zebra Jig', createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Apple Reel', createdAt: DateTime(2024, 1, 2)),
      _tune(id: 3, name: 'Mango Hornpipe', createdAt: DateTime(2024, 1, 3)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setSort(TuneSort.nameZA);

    final names = (await _awaitFilteredTunes(container)).map((t) => t.name).toList();
    expect(names, ['Zebra Jig', 'Mango Hornpipe', 'Apple Reel']);
  });

  test('filteredTunesProvider sorts oldestFirst', () async {
    final tunes = [
      _tune(id: 1, name: 'Newest', createdAt: DateTime(2024, 6)),
      _tune(id: 2, name: 'Oldest', createdAt: DateTime(2024)),
      _tune(id: 3, name: 'Middle', createdAt: DateTime(2024, 3)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);
    container.read(tuneFiltersProvider.notifier).setSort(TuneSort.oldestFirst);

    final names = (await _awaitFilteredTunes(container)).map((t) => t.name).toList();
    expect(names, ['Oldest', 'Middle', 'Newest']);
  });

  test('availableKeysProvider returns sorted distinct keys', () async {
    final tunes = [
      _tune(id: 1, name: "Cooley's", key: 'Em', createdAt: DateTime(2024)),
      _tune(id: 2, name: 'Lark in the Morning', key: 'D', createdAt: DateTime(2024, 1, 2)),
      _tune(id: 3, name: 'The Morning Dew', key: 'Em', createdAt: DateTime(2024, 1, 3)),
    ];
    final container = _container(tunes);
    addTearDown(container.dispose);

    final keys = await _awaitAvailableKeys(container);
    expect(keys, ['D', 'Em']);
  });

  test('TuneFiltersNotifier.clear resets state', () {
    final container = _container([]);
    addTearDown(container.dispose);

    final notifier = container.read(tuneFiltersProvider.notifier);
    notifier.setType(TuneType.jig);
    notifier.setKey('G');
    expect(container.read(tuneFiltersProvider).isActive, isTrue);

    notifier.clear();
    expect(container.read(tuneFiltersProvider), equals(const TuneFilters()));
  });
}
