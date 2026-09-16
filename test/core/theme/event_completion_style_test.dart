import 'dart:math' as math;

import 'package:daily/core/theme/event_completion_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strike maximizes weaker contrast without changing category colors', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance() + .05;
      final y = b.computeLuminance() + .05;
      return math.max(x, y) / math.min(x, y);
    }

    for (final surface in [
      Colors.black,
      Colors.white,
      const Color(0xff202020),
    ]) {
      for (final text in [
        Colors.black,
        Colors.white,
        Colors.yellow,
        Colors.red,
        Colors.blue,
        Colors.green,
        const Color(0xff808080),
        const Color(0xfffefefe),
        const Color(0xff010101),
      ]) {
        for (final alpha in [0.0, .08, .12, .15, .17, .18]) {
          final background = Color.alphaBlend(
            text.withValues(alpha: alpha),
            surface,
          );
          final result = calendarEventStrikeColor(text, background);
          final score = math.min(
            contrast(result, text),
            contrast(result, background),
          );
          for (var c = 0; c <= 255; c++) {
            final other = Color.fromARGB(255, c, c, c);
            expect(
              score + 1e-10,
              greaterThanOrEqualTo(
                math.min(contrast(other, text), contrast(other, background)),
              ),
            );
          }
          expect(result.a, 1);
        }
      }
    }
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'completed event remains legible with a single strike in ${brightness.name} mode',
      (tester) async {
        late TextStyle completedStyle;
        late Color completedAccent;
        late Color completedBackground;
        const categoryColor = Color(0xffef4444);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? ThemeData.light() : null,
            darkTheme: brightness == Brightness.dark ? ThemeData.dark() : null,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Builder(
              builder: (context) {
                completedStyle = calendarEventCompletionStyle(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  completed: true,
                  eventColor: categoryColor,
                );
                completedAccent = calendarEventAccentColor(
                  context,
                  categoryColor,
                  completed: true,
                );
                completedBackground = calendarEventBackgroundColor(
                  context,
                  categoryColor,
                  completed: true,
                );
                return Text('완료 일정', style: completedStyle);
              },
            ),
          ),
        );

        expect(completedStyle.decoration, TextDecoration.lineThrough);
        expect(completedStyle.decorationStyle, TextDecorationStyle.solid);
        expect(completedStyle.decorationThickness, lessThan(2));
        expect(completedStyle.color, categoryColor);
        expect(completedStyle.decorationColor, isNotNull);
        expect(completedStyle.color!.a, greaterThanOrEqualTo(0.7));
        expect(completedStyle.decorationColor!.a, greaterThanOrEqualTo(0.9));
        expect(completedAccent, categoryColor);
        expect(completedBackground, categoryColor.withValues(alpha: 0.12));
      },
    );
  }
}
