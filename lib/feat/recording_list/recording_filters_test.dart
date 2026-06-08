import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/recording_list/recording_filters.dart';
import 'package:tune_trove/model/database.dart';

void main() {
  Recording rec(int id, String name, {DateTime? createdAt}) => Recording(
    id: id,
    name: name,
    url: 'https://example.com/$id',
    createdAt: createdAt ?? DateTime(2020, 6, 15),
  );

  final a = rec(1, 'Banish Misfortune', createdAt: DateTime(2021, 6, 15));
  final b = rec(2, 'apple session', createdAt: DateTime(2023, 6, 15));
  final c = rec(3, 'Zydeco night', createdAt: DateTime(2022, 6, 15));
  final all = [a, b, c];

  group('applyRecordingFilters — tuneLink', () {
    test('hasTune keeps only recordings with a tune link', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(tuneLink: TuneLinkFilter.hasTune),
        {1, 3},
      );
      expect(result.map((r) => r.id), unorderedEquals([1, 3]));
    });

    test('noTune keeps only recordings without a tune link', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(tuneLink: TuneLinkFilter.noTune),
        {1, 3},
      );
      expect(result.map((r) => r.id), [2]);
    });

    test('any keeps everything regardless of links', () {
      final result = applyRecordingFilters(all, const RecordingFilters(), {1});
      expect(result, hasLength(3));
    });

    test('hasTune is empty when none are linked', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(tuneLink: TuneLinkFilter.hasTune),
        const {},
      );
      expect(result, isEmpty);
    });

    test('noTune returns all when none are linked', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(tuneLink: TuneLinkFilter.noTune),
        const {},
      );
      expect(result, hasLength(3));
    });
  });

  group('applyRecordingFilters — sort', () {
    test('name A–Z is case-insensitive', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(sort: RecordingSort.nameAZ),
        const {},
      );
      expect(result.map((r) => r.name), [
        'apple session',
        'Banish Misfortune',
        'Zydeco night',
      ]);
    });

    test('name Z–A is the reverse', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(sort: RecordingSort.nameZA),
        const {},
      );
      expect(result.map((r) => r.name), [
        'Zydeco night',
        'Banish Misfortune',
        'apple session',
      ]);
    });

    test('default sort is newest first by createdAt', () {
      final result = applyRecordingFilters(
        all,
        const RecordingFilters(),
        const {},
      );
      expect(result.map((r) => r.id), [2, 3, 1]);
    });
  });

  group('RecordingFilters', () {
    test('isActive reflects non-default state', () {
      expect(const RecordingFilters().isActive, isFalse);
      expect(
        const RecordingFilters(tuneLink: TuneLinkFilter.hasTune).isActive,
        isTrue,
      );
      expect(
        const RecordingFilters(tuneLink: TuneLinkFilter.noTune).isActive,
        isTrue,
      );
      expect(
        const RecordingFilters(sort: RecordingSort.nameAZ).isActive,
        isTrue,
      );
    });

    test('copyWith updates fields independently', () {
      const base = RecordingFilters();
      final linked = base.copyWith(tuneLink: TuneLinkFilter.hasTune);
      expect(linked.tuneLink, TuneLinkFilter.hasTune);
      expect(linked.sort, RecordingSort.dateAdded);
      expect(
        base.copyWith(sort: RecordingSort.nameZA).tuneLink,
        TuneLinkFilter.any,
      );
    });
  });
}
