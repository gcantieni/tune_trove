import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/shared_widgets/key_picker_sheet.dart';

void main() {
  // Pumps a button that opens the key picker sheet and forwards the pop result
  // to [onResult] once an action button is tapped.
  Future<void> pumpOpener(
    WidgetTester tester, {
    required void Function(String?) onResult,
    String? currentKey,
    String? defaultKey,
    String clearLabel = 'Clear',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                onResult(
                  await showKeyPickerSheet(
                    context,
                    currentKey: currentKey,
                    defaultKey: defaultKey,
                    clearLabel: clearLabel,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Done returns the previewed key', (tester) async {
    String? result = 'unset';
    await pumpOpener(tester, onResult: (v) => result = v, currentKey: 'GMix');
    expect(find.text('GMix'), findsWidgets); // preview reflects current key
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, 'GMix');
  });

  testWidgets('Clear pops an empty string', (tester) async {
    String? result = 'unset';
    await pumpOpener(
      tester,
      onResult: (v) => result = v,
      currentKey: 'D',
      clearLabel: 'Remove',
    );
    expect(find.text('Remove'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(result, '');
  });

  testWidgets('Cancel pops null', (tester) async {
    String? result = 'unset';
    await pumpOpener(tester, onResult: (v) => result = v, currentKey: 'D');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('Clear button is hidden when there is no current key', (
    tester,
  ) async {
    await pumpOpener(tester, onResult: (_) {});
    expect(find.text('Clear'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('default key label is rendered', (tester) async {
    await pumpOpener(
      tester,
      onResult: (_) {},
      currentKey: 'D',
      defaultKey: 'Ador',
    );
    expect(find.textContaining('default: Ador'), findsOneWidget);
  });

  testWidgets('initial preview reflects the passed current key', (
    tester,
  ) async {
    await pumpOpener(tester, onResult: (_) {}, currentKey: 'Bb');
    expect(find.text('Bb'), findsWidgets);
  });
}
