import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/feat/music_kit/mock_music_kit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockMusicKitService.lookupSong', () {
    late MockMusicKitService service;

    setUp(() => service = MockMusicKitService());
    tearDown(() => service.dispose());

    test('resolves a catalog id to metadata echoing the id', () async {
      final result = await service.lookupSong('789012');
      expect(result, isNotNull);
      expect(result!.id, '789012');
      expect(result.kind, 'song');
      expect(result.title, isNotEmpty);
    });

    test('returns null for the "unknown" sentinel', () async {
      expect(await service.lookupSong('unknown'), isNull);
    });
  });
}
