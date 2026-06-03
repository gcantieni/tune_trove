import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tune_trove/shared_widgets/timestamp_editor_dialog.dart';

typedef LinkResult = ({double? start, double? end, String? performedKey});

void main() {
  // Opens TimestampEditorDialog and forwards its pop result to [onResult].
  Future<void> pumpDialog(
    WidgetTester tester, {
    required void Function(Object?) onResult,
    double? initialStart,
    double? initialEnd,
    String? initialPerformedKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                onResult(
                  await showDialog<Object?>(
                    context: context,
                    builder: (_) => TimestampEditorDialog(
                      initialStart: initialStart,
                      initialEnd: initialEnd,
                      initialPerformedKey: initialPerformedKey,
                    ),
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

  testWidgets('populates fields from initial values', (tester) async {
    await pumpDialog(
      tester,
      onResult: (_) {},
      initialStart: 65.5,
      initialEnd: 130.0,
      initialPerformedKey: 'Ador',
    );
    expect(find.text('1:05.50'), findsOneWidget);
    expect(find.text('2:10.00'), findsOneWidget);
    expect(find.text('ADor'), findsOneWidget); // normalized for display
  });

  testWidgets('shows the placeholder when no performed key is set', (
    tester,
  ) async {
    await pumpDialog(tester, onResult: (_) {});
    expect(find.text('Tap to set (leave blank for none)'), findsOneWidget);
  });

  testWidgets('invalid time blocks save and shows a validator error', (
    tester,
  ) async {
    Object? result = 'unset';
    await pumpDialog(tester, onResult: (v) => result = v);
    await tester.enterText(find.byType(TextFormField).first, '1:99');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use m:ss.cc or seconds'), findsOneWidget);
    // Dialog is still open; nothing popped.
    expect(result, 'unset');
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save pops the parsed start/end/performedKey', (tester) async {
    Object? result = 'unset';
    await pumpDialog(
      tester,
      onResult: (v) => result = v,
      initialPerformedKey: 'D',
    );
    await tester.enterText(find.byType(TextFormField).at(0), '0:30.00');
    await tester.enterText(find.byType(TextFormField).at(1), '1:00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isA<LinkResult>());
    final r = result! as LinkResult;
    expect(r.start, closeTo(30.0, 1e-9));
    expect(r.end, closeTo(60.0, 1e-9));
    expect(r.performedKey, 'D');
  });

  testWidgets('empty time fields save as null', (tester) async {
    Object? result = 'unset';
    await pumpDialog(tester, onResult: (v) => result = v);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final r = result! as LinkResult;
    expect(r.start, isNull);
    expect(r.end, isNull);
    expect(r.performedKey, isNull);
  });

  testWidgets('Cancel pops null', (tester) async {
    Object? result = 'unset';
    await pumpDialog(tester, onResult: (v) => result = v);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('tapping performed key opens the key picker sheet', (
    tester,
  ) async {
    await pumpDialog(tester, onResult: (_) {});
    await tester.tap(find.text('Tap to set (leave blank for none)'));
    await tester.pumpAndSettle();
    // The key picker sheet exposes a Done action.
    expect(find.text('Done'), findsOneWidget);
  });
}
