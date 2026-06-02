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
}
