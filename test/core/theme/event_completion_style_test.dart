import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

import 'package:daily/core/theme/event_completion_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all RGB channels in steps of ten and 255 remain readable', () {
    final channels = [...List.generate(26, (i) => i * 10), 255];
    var count = 0;
    var adjustedBackgrounds = 0;
    final minimum = [double.infinity, double.infinity, double.infinity];
    const surfaces = [
      Colors.black,
      Color(0xff1c1c1e),
      Color(0xff252528),
      Color(0xff121212),
      Colors.white,
      Color(0xfff5f5fa),
      Color(0xfff0f0f5),
      Color(0xfffdfdfe),
    ];
    for (final surface in surfaces) {
      for (final alpha in [0.0, .07, .08, .12, 38 / 255, .15, .17, .18, .22]) {
        for (final r in channels) {
          for (final g in channels) {
            for (final b in channels) {
              final category = Color.fromARGB(255, r, g, b);
              final background = Color.alphaBlend(
                category.withValues(alpha: alpha),
                surface,
              );
              final palette = calendarEventPalette(category, background);
              if (palette.background.toARGB32() != background.toARGB32()) {
                adjustedBackgrounds++;
              }
              var pair = 0;
              void check(Color a, Color b, double target) {
                final x = a.computeLuminance() + .05;
                final y = b.computeLuminance() + .05;
                final ratio = math.max(x, y) / math.min(x, y);
                minimum[pair] = math.min(minimum[pair], ratio);
                pair++;
                if (ratio < target) {
                  fail(
                    'RGB($r,$g,$b) on $surface: $ratio < $target; '
                    '${palette.foreground}, ${palette.strike}, ${palette.background}',
                  );
                }
              }

              check(palette.foreground, palette.background, 4.5);
              check(palette.strike, palette.background, 3);
              check(palette.strike, palette.foreground, 3);
              if (palette.background.a != 1 ||
                  palette.foreground.a != 1 ||
                  palette.strike.a != 1) {
                fail('Non-opaque palette');
              }
              count++;
            }
          }
        }
      }
    }
    expect(count, 1417176);
    final report = {
      'rgbChannels': [...List.generate(26, (i) => i * 10), 255],
      'distinctColors': 19683,
      'surfaces': surfaces.map((c) => c.toARGB32().toRadixString(16)).toList(),
      'alphas': [0.0, .07, .08, .12, 38 / 255, .15, .17, .18, .22],
      'combinations': count,
      'minimumTitleBackground': minimum[0],
      'minimumStrikeBackground': minimum[1],
      'minimumStrikeTitle': minimum[2],
      'adjustedBackgrounds': adjustedBackgrounds,
      'failures': 0,
    };
    final output = Platform.environment['DAILY_CONTRAST_AUDIT_DIR'];
    if (output != null) {
      File(
        '$output/palette-metrics.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    }
    // ignore: avoid_print
    print('RGB full-grid audit: $report');
  });
  testWidgets('contrast uses all painted layers and survives a drag overlay', (
    tester,
  ) async {
    const category = Colors.yellow;
    const surface = Color(0xff1c1c1e);
    final tint = category.withValues(alpha: .15);
    late Color originalSurface;
    late TextStyle sourceStyle;
    late TextStyle overlayStyle;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Material(
          color: surface,
          child: Builder(
            builder: (context) {
              originalSurface = CalendarEventSurface.of(context);
              sourceStyle = calendarEventCompletionStyle(
                context,
                const TextStyle(fontSize: 10),
                completed: true,
                eventColor: category,
                backgroundColor: tint,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final composed = Color.alphaBlend(tint, surface);
    expect(
      sourceStyle.decorationColor,
      calendarEventStrikeColor(category, composed),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Material(
          color: Colors.red,
          child: CalendarEventSurface(
            color: originalSurface,
            child: Builder(
              builder: (context) {
                overlayStyle = calendarEventCompletionStyle(
                  context,
                  const TextStyle(fontSize: 10),
                  completed: true,
                  eventColor: category,
                  backgroundColor: tint,
                );
                return Text('Lifted event', style: overlayStyle);
              },
            ),
          ),
        ),
      ),
    );
    expect(overlayStyle, sourceStyle);
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
        expect(completedStyle.decorationThickness, greaterThanOrEqualTo(1.5));
        expect(
          calendarEventContrast(
            completedStyle.color!,
            brightness == Brightness.dark
                ? ThemeData.dark().scaffoldBackgroundColor
                : ThemeData.light().scaffoldBackgroundColor,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(completedStyle.decorationColor, isNotNull);
        expect(completedStyle.color!.a, greaterThanOrEqualTo(0.7));
        expect(completedStyle.decorationColor!.a, greaterThanOrEqualTo(0.9));
        expect(completedAccent, categoryColor);
        expect(completedBackground.a, 1);
      },
    );
  }
}
