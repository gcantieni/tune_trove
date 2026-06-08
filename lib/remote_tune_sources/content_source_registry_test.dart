import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';

void main() {
  group('allContentSources registry invariants', () {
    test('is non-empty', () {
      expect(allContentSources, isNotEmpty);
    });

    test('every id is unique', () {
      final ids = allContentSources.map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every name is unique (metaBySourceName relies on this)', () {
      final names = allContentSources.map((m) => m.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every source has a non-empty id, name, and attribution', () {
      for (final m in allContentSources) {
        expect(m.id, isNotEmpty, reason: 'id for ${m.name}');
        expect(m.name, isNotEmpty, reason: 'name for ${m.id}');
        expect(m.attribution, isNotEmpty, reason: 'attribution for ${m.id}');
      }
    });

    test('confirmation-required sources are not always-active', () {
      for (final m in allContentSources) {
        expect(m.isAlwaysActive, equals(!m.confirmationRequired),
            reason: m.id);
      }
    });

    test('metaBySourceName resolves every registered name', () {
      for (final m in allContentSources) {
        expect(metaBySourceName(allContentSources, m.name)?.id, equals(m.id));
      }
    });
  });

  group('compareSourcesForDisplay', () {
    ContentSourceMeta meta(String name, String genre) => ContentSourceMeta(
          id: name,
          name: name,
          genre: genre,
          license: '',
          attribution: '',
          confirmationRequired: false,
        );

    List<String> ordered(List<ContentSourceMeta> input) {
      final list = [...input]..sort(compareSourcesForDisplay);
      return list.map((m) => m.name).toList();
    }

    test('orders by market-priority genre: Irish, Scottish, English', () {
      expect(
        ordered([
          meta('e', 'English'),
          meta('s', 'Scottish'),
          meta('i', 'Irish'),
        ]),
        ['i', 's', 'e'],
      );
    });

    test('non-priority genres follow, with ungenred sources last', () {
      final result = ordered([
        meta('ungenred', ''),
        meta('newengland', 'New England'),
        meta('irish', 'Irish'),
      ]);
      expect(result, ['irish', 'newengland', 'ungenred']);
    });

    test('breaks ties within a genre by name', () {
      expect(
        ordered([
          meta('Beta', 'Irish'),
          meta('Alpha', 'Irish'),
        ]),
        ['Alpha', 'Beta'],
      );
    });

    test('ignores a leading "The" when alphabetizing within a genre', () {
      // "The Apple…" sorts under A (so before "Banana"), and "The Zebra…"
      // under Z (so last) — proving the leading "The" is dropped.
      expect(
        ordered([
          meta('The Zebra Collection', 'Scottish'),
          meta('Banana Reels', 'Scottish'),
          meta('The Apple Collection', 'Scottish'),
        ]),
        ['The Apple Collection', 'Banana Reels', 'The Zebra Collection'],
      );
    });

    test('on the real registry, The Athole Collection leads the Scottish '
        'section', () {
      final scottish = [...allContentSources.where((m) => m.genre == 'Scottish')]
        ..sort(compareSourcesForDisplay);
      expect(scottish.first.id, 'athole');
    });

    test('on the real registry, all Irish sources precede all Scottish', () {
      final sorted = [...allContentSources]..sort(compareSourcesForDisplay);
      final lastIrish = sorted.lastIndexWhere((m) => m.genre == 'Irish');
      final firstScottish = sorted.indexWhere((m) => m.genre == 'Scottish');
      expect(lastIrish, lessThan(firstScottish));
    });

    test('thesession.org is pinned last even against another ungenred source',
        () {
      // 'zzz' would otherwise sort after 'thesession' by name; the pin wins.
      final sorted = [
        meta('thesession', ''),
        meta('aaa', ''),
        meta('zzz', ''),
      ]..sort(compareSourcesForDisplay);
      expect(sorted.last.id, 'thesession');
    });

    test('on the real registry, thesession.org sorts dead last', () {
      final sorted = [...allContentSources]..sort(compareSourcesForDisplay);
      expect(sorted.last.id, 'thesession');
    });
  });

  group('Bremner Scots Reels source', () {
    final bremner =
        allContentSources.where((m) => m.id == 'bremner').toList();

    test('is registered as a GPL Scottish source requiring confirmation', () {
      expect(bremner, hasLength(1));
      expect(bremner.single.genre, 'Scottish');
      expect(bremner.single.license, 'GNU GPL');
      expect(bremner.single.confirmationRequired, isTrue);
    });

    test('builds a static-asset source', () {
      expect(buildTuneSource(bremner.single).name, bremner.single.name);
    });
  });
}
