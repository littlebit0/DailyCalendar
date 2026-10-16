import '../../events/domain/calendar_event.dart';
import '../../events/domain/event_category.dart';
import '../../events/domain/event_draft.dart';
import '../../events/domain/recurrence_rule.dart';
import '../domain/event_parse_result.dart';
import '../domain/schedule_parser.dart';

class RuleBasedScheduleParser implements ScheduleParser {
  static final _monthDayPattern = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일');
  static final _monthDayRangePattern = RegExp(
    r'(\d{1,2})\s*월\s*(\d{1,2})\s*일?\s*(?:부터|에서|~|-)\s*(?:(\d{1,2})\s*월\s*)?(\d{1,2})\s*일?\s*(?:까지)?',
  );
  static final _relativeDateRangePattern = RegExp(
    r'(오늘|내일|모레)\s*(?:부터|에서|~|-)\s*(오늘|내일|모레)\s*(?:까지)?',
  );
  static final _durationDaysPattern = RegExp(r'(\d{1,2})\s*일\s*(?:동안|간)');
  static final _durationNightsPattern = RegExp(
    r'(\d{1,2})\s*박\s*(\d{1,2})\s*일',
  );
  static final _timePattern = RegExp(
    r'(오전|오후|아침|점심|저녁|밤)?\s*(\d{1,2})(?:\s*시(?!간)|:)(?:\s*(\d{1,2})\s*분?)?',
  );
  static final _hourReminderPattern = RegExp(r'(\d{1,2})\s*시간\s*전');
  static final _minuteReminderPattern = RegExp(r'(\d{1,3})\s*분\s*전');

  @override
  Future<EventParseResult> parse(
    String input, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
  }) async {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return const EventParseResult(question: '등록할 일정 내용을 입력해 주세요.');
    }

    try {
      return _parse(
        normalized,
        baseDate: baseDate,
        selectedDate: selectedDate,
        defaultReminderMinutes: defaultReminderMinutes,
        defaultReminderMinutesList: defaultReminderMinutesList,
      );
    } on _InvalidScheduleInput catch (error) {
      return EventParseResult(question: error.message);
    }
  }

  EventParseResult _parse(
    String normalized, {
    required DateTime baseDate,
    DateTime? selectedDate,
    required int defaultReminderMinutes,
    List<int>? defaultReminderMinutesList,
  }) {
    // A reminder such as "2시간 전" must not also be read as a start/end time.
    final reminder = _parseReminder(normalized);
    final schedule = _withoutReminders(normalized);
    final dateRange = _parseDateRange(schedule, baseDate, selectedDate);
    final date =
        dateRange?.startDate ?? _parseDate(schedule, baseDate, selectedDate);
    final parsedTimes = _parseTimes(schedule);
    final parsedTime = parsedTimes.isEmpty ? null : parsedTimes[0];
    final parsedEndTime = parsedTimes.length > 1 ? parsedTimes[1] : null;
    final reminders = reminder == null
        ? normalizeReminderMinutes(
            defaultReminderMinutesList ?? [defaultReminderMinutes],
          )
        : <int>[reminder];
    final recurrence = _parseRecurrence(normalized);
    final title = _cleanTitle(normalized);
    final category = EventCategory.classify(normalized);
    final allDay = parsedTime == null && parsedEndTime == null;

    final startAt = parsedTime == null
        ? DateTime(date.year, date.month, date.day)
        : DateTime(
            date.year,
            date.month,
            date.day,
            parsedTime.hour,
            parsedTime.minute,
          );
    final endAt = _resolveEndAt(
      startAt: startAt,
      endDate: dateRange?.endDate,
      endTime: parsedEndTime,
      allDay: allDay,
    );

    return EventParseResult(
      draft: EventDraft(
        title: title.isEmpty ? '새 일정' : title,
        startAt: startAt,
        endAt: endAt,
        allDay: allDay,
        category: category,
        colorValue: category.colorValue,
        reminderMinutesBeforeList: allDay ? const <int>[] : reminders,
        recurrence: recurrence,
      ),
    );
  }

  _ParsedDateRange? _parseDateRange(
    String input,
    DateTime baseDate,
    DateTime? selectedDate,
  ) {
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);

    final monthDayRange = _monthDayRangePattern.firstMatch(input);
    if (monthDayRange != null) {
      final startMonth = int.parse(monthDayRange.group(1)!);
      final startDay = int.parse(monthDayRange.group(2)!);
      final endMonth = int.tryParse(monthDayRange.group(3) ?? '') ?? startMonth;
      final endDay = int.parse(monthDayRange.group(4)!);
      final startDate = _resolveMonthDay(startMonth, startDay, today);
      return _ParsedDateRange(
        startDate,
        _resolveRangeEnd(startDate, endMonth, endDay),
      );
    }

    final monthDays = _monthDayPattern.allMatches(input).toList();
    if (monthDays.length >= 2 && _hasRangeConnector(input)) {
      final startMatch = monthDays[0];
      final endMatch = monthDays[1];
      final startDate = _resolveMonthDay(
        int.parse(startMatch.group(1)!),
        int.parse(startMatch.group(2)!),
        today,
      );
      return _ParsedDateRange(
        startDate,
        _resolveRangeEnd(
          startDate,
          int.parse(endMatch.group(1)!),
          int.parse(endMatch.group(2)!),
        ),
      );
    }

    final relativeRange = _relativeDateRangePattern.firstMatch(input);
    if (relativeRange != null) {
      final startDate = _resolveRelativeDate(relativeRange.group(1)!, today);
      var endDate = _resolveRelativeDate(relativeRange.group(2)!, today);
      if (endDate.isBefore(startDate)) {
        endDate = startDate;
      }
      return _ParsedDateRange(startDate, endDate);
    }

    final nights = _durationNightsPattern.firstMatch(input);
    if (nights != null) {
      final days = int.parse(nights.group(2)!);
      final startDate = _parseDate(input, baseDate, selectedDate);
      return _ParsedDateRange(
        startDate,
        startDate.add(Duration(days: (days - 1).clamp(0, 3650).toInt())),
      );
    }

    final durationDays = _durationDaysPattern.firstMatch(input);
    if (durationDays != null) {
      final days = int.parse(durationDays.group(1)!);
      final startDate = _parseDate(input, baseDate, selectedDate);
      return _ParsedDateRange(
        startDate,
        startDate.add(Duration(days: (days - 1).clamp(0, 3650).toInt())),
      );
    }

    return null;
  }

  bool _hasRangeConnector(String input) {
    return input.contains('부터') ||
        input.contains('까지') ||
        input.contains('에서') ||
        input.contains('~');
  }

  DateTime _parseDate(String input, DateTime baseDate, DateTime? selectedDate) {
    final today = DateTime(baseDate.year, baseDate.month, baseDate.day);
    if (input.contains('모레')) {
      return today.add(const Duration(days: 2));
    }
    if (input.contains('내일')) {
      return today.add(const Duration(days: 1));
    }
    if (input.contains('오늘')) {
      return today;
    }

    final monthDay = _monthDayPattern.firstMatch(input);
    if (monthDay != null) {
      final month = int.parse(monthDay.group(1)!);
      final day = int.parse(monthDay.group(2)!);
      return _resolveMonthDay(month, day, today);
    }

    final weekday = _parseWeekday(input);
    if (weekday != null) {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final isNextWeek = input.contains('다음 주') || input.contains('다음주');
      final candidate = startOfWeek.add(
        Duration(days: weekday - 1 + (isNextWeek ? 7 : 0)),
      );
      if (!isNextWeek && candidate.isBefore(today)) {
        return candidate.add(const Duration(days: 7));
      }
      return candidate;
    }

    if (selectedDate != null) {
      return DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    }
    return today;
  }

  /// The date only when [month]/[day] really exist in [year] (no overflow into
  /// another month, as the DateTime constructor would do).
  DateTime? _exactDate(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  DateTime _resolveMonthDay(int month, int day, DateTime today) {
    final earliest = today.subtract(const Duration(days: 1));
    // Eight years is enough to reach the next 29 February.
    for (var year = today.year; year <= today.year + 8; year++) {
      final date = _exactDate(year, month, day);
      if (date != null && !date.isBefore(earliest)) return date;
    }
    throw _InvalidScheduleInput('$month월 $day일은 올바른 날짜가 아닙니다. 날짜를 확인해 주세요.');
  }

  DateTime _resolveRangeEnd(DateTime start, int month, int day) {
    final end =
        _exactDate(start.year, month, day) ??
        (throw _InvalidScheduleInput(
          '$month월 $day일은 올바른 날짜가 아닙니다. 날짜를 확인해 주세요.',
        ));
    if (!end.isBefore(start)) return end;
    return _exactDate(start.year + 1, month, day) ??
        (throw _InvalidScheduleInput(
          '$month월 $day일은 올바른 날짜가 아닙니다. 날짜를 확인해 주세요.',
        ));
  }

  DateTime _resolveRelativeDate(String value, DateTime today) {
    return switch (value) {
      '모레' => today.add(const Duration(days: 2)),
      '내일' => today.add(const Duration(days: 1)),
      _ => today,
    };
  }

  List<_ParsedTime> _parseTimes(String input) {
    final times = <_ParsedTime>[];
    String? previousMarker;
    for (final match in _timePattern.allMatches(input)) {
      times.add(_parseTimeMatch(match, previousMarker));
      previousMarker = match.group(1) ?? previousMarker;
    }
    return times;
  }

  _ParsedTime _parseTimeMatch(RegExpMatch match, String? fallbackMarker) {
    final marker = match.group(1) ?? fallbackMarker;
    var hour = int.parse(match.group(2)!);
    final minute = int.tryParse(match.group(3) ?? '') ?? 0;

    final isPm =
        marker == '오후' || marker == '저녁' || marker == '밤' || marker == '점심';
    final isAm = marker == '오전' || marker == '아침';

    if (isPm && hour < 12) {
      hour += 12;
    }
    if (isAm && hour == 12) {
      hour = 0;
    }
    if (hour > 23 || minute > 59) {
      throw _InvalidScheduleInput(
        '${match.group(0)!.trim()}은 올바른 시각이 아닙니다. 시각을 확인해 주세요.',
      );
    }
    return _ParsedTime(hour, minute);
  }

  DateTime _resolveEndAt({
    required DateTime startAt,
    required DateTime? endDate,
    required _ParsedTime? endTime,
    required bool allDay,
  }) {
    if (endDate != null) {
      if (allDay) {
        return DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
        ).add(const Duration(days: 1));
      }
      if (endTime != null) {
        final endAt = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          endTime.hour,
          endTime.minute,
        );
        return endAt.isAfter(startAt)
            ? endAt
            : endAt.add(const Duration(days: 1));
      }
      return DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ).add(const Duration(days: 1));
    }

    if (endTime != null) {
      final endAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        endTime.hour,
        endTime.minute,
      );
      return endAt.isAfter(startAt)
          ? endAt
          : endAt.add(const Duration(days: 1));
    }

    return allDay
        ? startAt.add(const Duration(days: 1))
        : startAt.add(const Duration(hours: 1));
  }

  String _withoutReminders(String input) => input
      .replaceAll(_hourReminderPattern, ' ')
      .replaceAll(_minuteReminderPattern, ' ');

  int? _parseReminder(String input) {
    final hour = _hourReminderPattern.firstMatch(input);
    if (hour != null) {
      return int.parse(hour.group(1)!) * 60;
    }
    final minute = _minuteReminderPattern.firstMatch(input);
    if (minute != null) {
      return int.parse(minute.group(1)!);
    }
    return null;
  }

  RecurrenceRule _parseRecurrence(String input) {
    final frequency = switch (input) {
      final text when text.contains('매일') => RecurrenceFrequency.daily,
      final text when text.contains('매주') => RecurrenceFrequency.weekly,
      final text when text.contains('매월') => RecurrenceFrequency.monthly,
      final text when text.contains('매년') => RecurrenceFrequency.yearly,
      _ => RecurrenceFrequency.none,
    };
    return RecurrenceRule(frequency: frequency);
  }

  int? _parseWeekday(String input) {
    const weekdays = {
      '월': DateTime.monday,
      '화': DateTime.tuesday,
      '수': DateTime.wednesday,
      '목': DateTime.thursday,
      '금': DateTime.friday,
      '토': DateTime.saturday,
      '일': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (input.contains('${entry.key}요일')) {
        return entry.value;
      }
    }
    return null;
  }

  String _cleanTitle(String input) {
    var value = input;
    final removalPatterns = [
      _monthDayRangePattern,
      _relativeDateRangePattern,
      _durationNightsPattern,
      _durationDaysPattern,
      _monthDayPattern,
      // Reminders first: otherwise the time pattern eats the "20분" of "20분 전".
      _hourReminderPattern,
      _minuteReminderPattern,
      _timePattern,
      RegExp(r'오늘|내일|모레|이번 주|이번주|다음 주|다음주'),
      RegExp(r'월요일|화요일|수요일|목요일|금요일|토요일|일요일'),
      RegExp(r'매일|매주|매월|매년'),
      RegExp(r'부터|까지|에서'),
      RegExp(r'알림|일정|등록|넣어줘|추가해줘|잡아줘|해줘'),
      RegExp(r'[,，]'),
    ];
    for (final pattern in removalPatterns) {
      value = value.replaceAll(pattern, ' ');
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _InvalidScheduleInput implements Exception {
  const _InvalidScheduleInput(this.message);

  final String message;
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);

  final int hour;
  final int minute;
}

class _ParsedDateRange {
  const _ParsedDateRange(this.startDate, this.endDate);

  final DateTime startDate;
  final DateTime endDate;
}
