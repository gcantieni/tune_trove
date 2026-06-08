import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/util/search_normalize.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases input', () {
      expect(normalizeForSearch('COOLEY'), equals('cooley'));
    });

    test('straight apostrophe passes through unchanged', () {
      expect(normalizeForSearch("Cooley's"), equals("cooley's"));
    });

    test(
      'right single quote (curly apostrophe) maps to straight apostrophe',
      () {
        expect(normalizeForSearch('Cooley’s'), equals("cooley's"));
      },
    );

    test('left single quote maps to straight apostrophe', () {
      expect(normalizeForSearch('Cooley‘s'), equals("cooley's"));
    });

    test('backtick maps to straight apostrophe', () {
      expect(normalizeForSearch('Cooley`s'), equals("cooley's"));
    });

    test('modifier letter apostrophe maps to straight apostrophe', () {
      expect(normalizeForSearch('Cooleyʼs'), equals("cooley's"));
    });

    test('prime maps to straight apostrophe', () {
      expect(normalizeForSearch('Cooley′s'), equals("cooley's"));
    });

    test('unrelated characters are not modified', () {
      expect(
        normalizeForSearch('Lark in the Morning'),
        equals('lark in the morning'),
      );
    });

    test('mixed: curly apostrophe + regular text', () {
      final query = normalizeForSearch('O’Neill');
      expect(query, equals("o'neill"));
    });

    test('empty string returns empty', () {
      expect(normalizeForSearch(''), equals(''));
    });
  });
}
