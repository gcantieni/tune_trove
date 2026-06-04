import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';

ContentSourceMeta _meta({
  String id = 'x',
  String name = 'X',
  bool confirmationRequired = false,
  bool? bundled,
  bool hidden = false,
}) {
  return ContentSourceMeta(
    id: id,
    name: name,
    genre: '',
    license: 'Public Domain',
    attribution: '',
    confirmationRequired: confirmationRequired,
    bundled: bundled,
    hidden: hidden,
  );
}

void main() {
  group('ContentSourceMeta.isAlwaysActive', () {
    test('true when no confirmation required', () {
      expect(_meta().isAlwaysActive, isTrue);
    });

    test('false when confirmation required', () {
      expect(_meta(confirmationRequired: true).isAlwaysActive, isFalse);
    });
  });

  group('ContentSourceMeta.bundled default', () {
    test('defaults to true for a visible source', () {
      expect(_meta().bundled, isTrue);
    });

    test('defaults to false for a hidden source', () {
      expect(_meta(hidden: true).bundled, isFalse);
    });

    test('explicit bundled value overrides the hidden-derived default', () {
      expect(_meta(hidden: true, bundled: true).bundled, isTrue);
      expect(_meta(bundled: false).bundled, isFalse);
    });
  });

  group('metaBySourceName', () {
    final registry = [
      _meta(id: 'a', name: 'Alpha'),
      _meta(id: 'b', name: 'Beta'),
    ];

    test('finds a source by exact name', () {
      expect(metaBySourceName(registry, 'Beta')?.id, equals('b'));
    });

    test('returns null for an unknown name', () {
      expect(metaBySourceName(registry, 'Gamma'), isNull);
    });

    test('returns null for a null name', () {
      expect(metaBySourceName(registry, null), isNull);
    });

    test('is case-sensitive', () {
      expect(metaBySourceName(registry, 'alpha'), isNull);
    });
  });

  group('metaBySourceId', () {
    final registry = [
      _meta(id: 'a', name: 'Alpha'),
      _meta(id: 'b', name: 'Beta'),
    ];

    test('finds a source by exact id', () {
      expect(metaBySourceId(registry, 'b')?.name, equals('Beta'));
    });

    test('returns null for an unknown id', () {
      expect(metaBySourceId(registry, 'c'), isNull);
    });

    test('returns null for a null id', () {
      expect(metaBySourceId(registry, null), isNull);
    });
  });
}
