import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tune_trove/remote_tune_sources/source_confirmation_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SourceConfirmationService', () {
    test('isConfirmed returns false for unknown source', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      expect(service.isConfirmed('foo'), isFalse);
    });

    test('confirm persists so isConfirmed returns true', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('paulhardy', 'CC BY-NC-SA 4.0');
      expect(service.isConfirmed('paulhardy'), isTrue);
    });

    test('confirmedIds returns all confirmed ids', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('paulhardy', 'CC BY-NC-SA 4.0');
      await service.confirm('norbeck', 'Free for personal use');
      expect(
        service.confirmedIds(),
        containsAll(['paulhardy', 'norbeck']),
      );
    });

    test('confirmedIds does not include non-confirmed sources', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('paulhardy', 'CC BY-NC-SA 4.0');
      expect(service.confirmedIds(), isNot(contains('norbeck')));
    });

    test('revoke removes the confirmation', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('paulhardy', 'CC BY-NC-SA 4.0');
      await service.revoke('paulhardy');
      expect(service.isConfirmed('paulhardy'), isFalse);
    });

    test('confirmedIds does not include revoked source', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('paulhardy', 'CC BY-NC-SA 4.0');
      await service.confirm('norbeck', 'Free for personal use');
      await service.revoke('paulhardy');
      expect(service.confirmedIds(), contains('norbeck'));
      expect(service.confirmedIds(), isNot(contains('paulhardy')));
    });

    test('confirm stores ISO 8601 timestamp and license in prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceConfirmationService(prefs);
      await service.confirm('thesession', 'CC BY-NC-SA 3.0');
      final raw = prefs.getString('confirmed_source_thesession');
      expect(raw, isNotNull);
      expect(raw, contains('CC BY-NC-SA 3.0'));
      expect(raw, contains('confirmedAt'));
    });
  });
}
