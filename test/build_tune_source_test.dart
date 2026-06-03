import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/remote_tune_sources/content_source_meta.dart';
import 'package:tune_trove/remote_tune_sources/content_source_registry.dart';

void main() {
  group('buildTuneSource', () {
    test('builds a source for every registered content source', () {
      for (final meta in allContentSources) {
        final source = buildTuneSource(meta);
        expect(source.name, meta.name, reason: meta.id);
      }
    });

    test('throws ArgumentError for an unknown source id', () {
      const bogus = ContentSourceMeta(
        id: 'does_not_exist',
        name: 'Bogus',
        genre: '',
        license: '',
        attribution: '',
        confirmationRequired: false,
      );
      expect(() => buildTuneSource(bogus), throwsArgumentError);
    });
  });
}
