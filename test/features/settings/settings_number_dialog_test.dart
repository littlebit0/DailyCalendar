import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<int?>> open(
    WidgetTester tester, {
    required ({int min, int max}) range,
    required int initialValue,
    Locale locale = const Locale('ko'),
  }) async {
    final results = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showSettingsNumberDialog(
                context: context,
                title: 'title',
                label: 'label',
                initialValue: initialValue,
                range: range,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> apply(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('D-day offsets accept a newly typed negative number', (
    tester,
  ) async {
    final results = await open(
      tester,
      range: customDdayOffsetRange,
      initialValue: -7,
    );
    // The plain number pad has no minus key on iOS.
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      const TextInputType.numberWithOptions(signed: true),
    );

    await apply(tester, '-3');

    expect(results, [-3]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('invalid D-day entries keep the dialog open with an error', (
    tester,
  ) async {
    final results = await open(
      tester,
      range: customDdayOffsetRange,
      initialValue: -7,
    );

    for (final invalid in ['abc', '', '99999999', '-366', '366', '1.5']) {
      await apply(tester, invalid);
      expect(find.byType(AlertDialog), findsOneWidget, reason: invalid);
      expect(find.text('-365~365 사이의 숫자를 입력하세요'), findsOneWidget);
    }
    expect(results, isEmpty);

    await apply(tester, '365');
    expect(results, [365]);
  });

  testWidgets('reminder minutes reject negative and oversized values', (
    tester,
  ) async {
    final results = await open(
      tester,
      range: customReminderMinutesRange,
      initialValue: 10,
      locale: const Locale('en'),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      const TextInputType.numberWithOptions(),
    );

    for (final invalid in ['-5', 'abc', '999999999999', '40321']) {
      await apply(tester, invalid);
      expect(find.byType(AlertDialog), findsOneWidget, reason: invalid);
      expect(find.text('Enter a number from 0 to 40320'), findsOneWidget);
    }
    expect(results, isEmpty);

    await apply(tester, '40320');
    expect(results, [40320]);
  });

  testWidgets('cancel still returns nothing', (tester) async {
    final results = await open(
      tester,
      range: customDdayOffsetRange,
      initialValue: -7,
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });
}
