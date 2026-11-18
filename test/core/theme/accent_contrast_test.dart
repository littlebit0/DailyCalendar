import 'package:daily/core/theme/calendar_date_color.dart';
import 'package:daily/core/theme/daily_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const _darkBackgrounds = [
  Color(0xff000000),
  Color(0xff0a0b0d),
  Color(0xff1b2029),
  Color(0xff1c1c1e),
  Color(0xff252528),
];

const _lightBackgrounds = [
  Color(0xffffffff),
  Color(0xfff5f5fa),
  Color(0xfffbfbfd),
];

void main() {
  final saturday = DateTime(2026, 11, 21);
  final sunday = DateTime(2026, 11, 22);
  final monday = DateTime(2026, 11, 23);

  for (final (brightness, backgrounds) in [
    (Brightness.dark, _darkBackgrounds),
    (Brightness.light, _lightBackgrounds),
  ]) {
    test('accent text colors meet WCAG AA 4.5:1 in $brightness', () {
      final colors = {
        'primary': DailyUi.primaryForegroundFor(brightness),
        'sunday': calendarSundayAccent(brightness),
        'saturday': calendarSaturdayAccent(brightness),
      };
      for (final MapEntry(:key, :value) in colors.entries) {
        for (final background in backgrounds) {
          expect(
            _contrast(value, background),
            greaterThanOrEqualTo(4.5),
            reason: '$key on $background',
          );
        }
      }
    });
  }

  test('accent colors are selected by brightness', () {
    expect(DailyUi.primaryForegroundFor(Brightness.light), DailyUi.primary);
    expect(
      DailyUi.primaryForegroundFor(Brightness.dark),
      const Color(0xff78a7ff),
    );
    expect(calendarSaturdayAccent(Brightness.light), const Color(0xff2563eb));
    expect(calendarSaturdayAccent(Brightness.dark), const Color(0xff60a5fa));
    expect(calendarSundayAccent(Brightness.light), const Color(0xffb91c1c));
    expect(calendarSundayAccent(Brightness.dark), const Color(0xfff87171));
  });

  test('calendarDateAccent follows brightness and keeps holiday color', () {
    Color? accent(
      DateTime date,
      Brightness brightness, {
      bool holiday = false,
    }) => calendarDateAccent(
      date,
      isHoliday: holiday,
      holidayColorValue: 0xff123456,
      brightness: brightness,
    );

    expect(accent(sunday, Brightness.dark), const Color(0xfff87171));
    expect(accent(sunday, Brightness.light), const Color(0xffb91c1c));
    expect(accent(saturday, Brightness.dark), const Color(0xff60a5fa));
    expect(accent(saturday, Brightness.light), const Color(0xff2563eb));
    expect(accent(monday, Brightness.dark), isNull);
    expect(
      accent(monday, Brightness.dark, holiday: true),
      const Color(0xff123456),
    );
  });
}
