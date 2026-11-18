import 'package:daily/core/calendar/calendar_period_label.dart';
import 'package:daily/core/localization/traditional_chinese_date_symbols.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('calendarWeekOfMonth', () {
    test('uses the configured first weekday at month boundaries', () {
      final augustFirst = DateTime(2026, 8);

      expect(calendarWeekOfMonth(augustFirst, weekStartsOnMonday: false), 1);
      expect(
        calendarWeekOfMonth(DateTime(2026, 8, 2), weekStartsOnMonday: false),
        2,
      );
      expect(calendarWeekOfMonth(augustFirst, weekStartsOnMonday: true), 1);
      expect(
        calendarWeekOfMonth(DateTime(2026, 8, 3), weekStartsOnMonday: true),
        2,
      );
    });
  });

  group('calendarPeriodLabel', () {
    String label({
      required CalendarViewMode viewMode,
      required String locale,
      DateTime? selectedDate,
    }) {
      return calendarPeriodLabel(
        visibleMonth: DateTime(2026, 8),
        selectedDate: selectedDate ?? DateTime(2026, 8, 15),
        viewMode: viewMode,
        navigationMode: MonthNavigationMode.vertical,
        locale: locale,
        weekStartsOnMonday: false,
        compactHorizontalYearOnly: false,
      );
    }

    test('week view shows localized year month and month week number', () {
      expect(
        label(viewMode: CalendarViewMode.week, locale: 'ko'),
        '2026년 8월 3주차',
      );
      expect(
        label(viewMode: CalendarViewMode.week, locale: 'en'),
        'August 2026 · Week 3',
      );
      expect(
        label(viewMode: CalendarViewMode.week, locale: 'ja'),
        '2026年8月 第3週',
      );
      expect(
        label(viewMode: CalendarViewMode.week, locale: 'zh-Hant'),
        '2026年8月 · 第3週',
      );
    });

    test('day view shows year and month without a week number', () {
      final result = label(viewMode: CalendarViewMode.day, locale: 'ko');

      expect(result, '2026년 8월');
      expect(result, isNot(contains('주차')));
    });

    test('week view follows the selected date across year boundaries', () {
      expect(
        label(
          viewMode: CalendarViewMode.week,
          locale: 'ko',
          selectedDate: DateTime(2027, 1, 1),
        ),
        '2027년 1월 1주차',
      );
    });

    test('month view keeps the vertical navigation year-only label', () {
      expect(label(viewMode: CalendarViewMode.month, locale: 'ko'), '2026년');
    });
  });

  group('calendarTimeLabel', () {
    setUpAll(registerTraditionalChineseDateSymbols);

    final midnight = DateTime(2026, 8, 17);
    final noon = DateTime(2026, 8, 17, 12);
    final afternoon = DateTime(2026, 8, 17, 15, 5);

    List<String> labels(String locale, {required bool use24HourTime}) => [
      for (final value in [midnight, noon, afternoon])
        calendarTimeLabel(value, locale: locale, use24HourTime: use24HourTime),
    ];

    test('24-hour setting keeps the locale 24-hour form', () {
      expect(labels('ko', use24HourTime: true), ['00:00', '12:00', '15:05']);
      expect(labels('en', use24HourTime: true), ['00:00', '12:00', '15:05']);
      expect(labels('ja', use24HourTime: true), ['0:00', '12:00', '15:05']);
      expect(labels('zh-Hant', use24HourTime: true), [
        '00:00',
        '12:00',
        '15:05',
      ]);
    });

    test(
      '12-hour setting uses the locale 12-hour form at midnight and noon',
      () {
        expect(labels('ko', use24HourTime: false), [
          '오전 12:00',
          '오후 12:00',
          '오후 3:05',
        ]);
        expect(labels('en', use24HourTime: false), [
          '12:00\u202fAM',
          '12:00\u202fPM',
          '3:05\u202fPM',
        ]);
        expect(labels('zh-Hant', use24HourTime: false), [
          '上午12:00',
          '下午12:00',
          '下午3:05',
        ]);
        // Japanese CLDR has no 12-hour `jm` pattern; the timeline already shows
        // the same 24-hour form.
        expect(labels('ja', use24HourTime: false), ['0:00', '12:00', '15:05']);
      },
    );
  });
}
