import 'package:intl/intl.dart';

import '../settings/app_settings.dart';

int calendarWeekOfMonth(DateTime date, {required bool weekStartsOnMonday}) {
  final firstDay = DateTime(date.year, date.month);
  final leadingDays = weekStartsOnMonday
      ? firstDay.weekday - DateTime.monday
      : firstDay.weekday % DateTime.daysPerWeek;
  return (leadingDays + date.day - 1) ~/ DateTime.daysPerWeek + 1;
}

String calendarPeriodLabel({
  required DateTime visibleMonth,
  required DateTime selectedDate,
  required CalendarViewMode viewMode,
  required MonthNavigationMode navigationMode,
  required String locale,
  required bool weekStartsOnMonday,
  required bool compactHorizontalYearOnly,
  bool showFullDay = false,
}) {
  if (showFullDay && viewMode == CalendarViewMode.day) {
    return locale.toLowerCase().startsWith('ko')
        ? DateFormat('yyyy년 MM월 dd일 EEEE', locale).format(selectedDate)
        : DateFormat.yMMMMEEEEd(locale).format(selectedDate);
  }
  if (navigationMode != MonthNavigationMode.vertical) {
    return compactHorizontalYearOnly
        ? DateFormat.y(locale).format(visibleMonth)
        : DateFormat.yMMMM(locale).format(visibleMonth);
  }

  return switch (viewMode) {
    CalendarViewMode.month => DateFormat.y(locale).format(visibleMonth),
    CalendarViewMode.day => DateFormat.yMMMM(locale).format(selectedDate),
    CalendarViewMode.week => _localizedWeekLabel(
      selectedDate,
      locale: locale,
      weekStartsOnMonday: weekStartsOnMonday,
    ),
  };
}

String _localizedWeekLabel(
  DateTime date, {
  required String locale,
  required bool weekStartsOnMonday,
}) {
  final yearMonth = DateFormat.yMMMM(locale).format(date);
  final week = calendarWeekOfMonth(
    date,
    weekStartsOnMonday: weekStartsOnMonday,
  );
  final languageCode = locale.toLowerCase().split(RegExp('[-_]')).first;
  return switch (languageCode) {
    'ko' => '$yearMonth $week주차',
    'ja' => '$yearMonth 第$week週',
    'zh' => '$yearMonth · 第$week週',
    _ => '$yearMonth · Week $week',
  };
}
