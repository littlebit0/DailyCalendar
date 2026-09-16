import 'package:daily/core/localization/app_localizations.dart';
import 'package:daily/features/settings/presentation/category_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ValueChanged<int?> onClose, {
    Locale locale = const Locale('ko'),
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  onClose(await showCategoryColorPicker(context, 0xff2563eb)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('preset is returned only on apply; cancelling does not save', (
    tester,
  ) async {
    int? saved;
    var calls = 0;
    await open(tester, (color) {
      saved = color;
      calls++;
    });
    await tester.tap(find.byKey(ValueKey('category-color-${0xff10b981}')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(calls, 1);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('category-color-${0xff10b981}')));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(saved, 0xff10b981);
  });

  testWidgets(
    'rainbow palette supports dragging and RGB values without saving until confirmed',
    (tester) async {
      int? saved;
      await open(tester, (color) => saved = color);
      await tester.tap(find.byTooltip('사용자 지정 색상'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      final palette = find.byKey(const Key('category-color-palette'));
      expect(palette, findsOneWidget);
      await tester.drag(palette, const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(3));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '18');
      await tester.enterText(fields.at(1), '52');
      await tester.enterText(fields.at(2), '86');
      await tester.tap(find.text('적용').last);
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(
        find.byKey(ValueKey('category-color-${0xff123456}')),
        findsOneWidget,
      );
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(saved, 0xff123456);
    },
  );

  for (final locale in AppLocalizations.supportedLocales) {
    for (final brightness in Brightness.values) {
      testWidgets('compact palette fits $locale $brightness with large text', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await open(
          tester,
          (_) {},
          locale: locale,
          brightness: brightness,
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
        for (final chip in find.byType(ChoiceChip).evaluate()) {
          final size = tester.getSize(
            find.byElementPredicate((e) => e == chip),
          );
          expect(size.width, size.height);
        }
      });
    }
  }
}
