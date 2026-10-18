import 'dart:convert';

enum RecurrenceFrequency {
  none('반복 없음'),
  daily('매일'),
  weekly('매주'),
  monthly('매월'),
  yearly('매년');

  const RecurrenceFrequency(this.label);

  final String label;

  static RecurrenceFrequency fromName(String? name) {
    if (name == null || name.isEmpty) {
      return RecurrenceFrequency.none;
    }
    return RecurrenceFrequency.values.firstWhere(
      (frequency) => frequency.name == name || frequency.label == name,
      orElse: () => RecurrenceFrequency.none,
    );
  }
}

class RecurrenceRule {
  const RecurrenceRule({
    this.frequency = RecurrenceFrequency.none,
    this.interval = 1,
    this.until,
    this.count,
    this.anchorDay,
    this.excludedDates = const <DateTime>[],
    this.byDay = const <String>[],
    this.byMonthDay = const <int>[],
    this.byMonth = const <int>[],
    this.bySetPos = const <int>[],
    this.rawRule,
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? until;
  final int? count;
  final int? anchorDay;
  final List<DateTime> excludedDates;

  /// RFC 5545 BYDAY tokens such as `MO`, `2TU` or `-1FR`.
  final List<String> byDay;

  /// RFC 5545 BYMONTHDAY values; negative values count from the month end.
  final List<int> byMonthDay;
  final List<int> byMonth;
  final List<int> bySetPos;

  /// Original RRULE text kept when its conditions cannot be expressed here.
  /// The event does not repeat in that case; the text is only preserved.
  final String? rawRule;

  bool get isRepeating => frequency != RecurrenceFrequency.none;

  /// True when the rule has conditions beyond frequency, interval and end.
  bool get hasDetails =>
      byDay.isNotEmpty ||
      byMonthDay.isNotEmpty ||
      byMonth.isNotEmpty ||
      bySetPos.isNotEmpty;

  /// Stored form of the detail conditions; null when there are none.
  String? get detailsJson => hasDetails || rawRule != null
      ? jsonEncode({
          if (byDay.isNotEmpty) 'byDay': byDay,
          if (byMonthDay.isNotEmpty) 'byMonthDay': byMonthDay,
          if (byMonth.isNotEmpty) 'byMonth': byMonth,
          if (bySetPos.isNotEmpty) 'bySetPos': bySetPos,
          if (rawRule != null) 'rawRule': rawRule,
        })
      : null;

  static final _byDayToken = RegExp(r'^[+-]?\d{0,2}(MO|TU|WE|TH|FR|SA|SU)$');

  /// Reads [detailsJson]; unreadable or invalid values are ignored.
  static RecurrenceRule withDetailsJson(RecurrenceRule rule, Object? raw) {
    if (raw == null) return rule;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return rule;
      List<int> ints(Object? value) => value is List
          ? value.whereType<num>().map((n) => n.toInt()).toList()
          : const <int>[];
      final days = decoded['byDay'];
      return rule.copyWith(
        byDay: days is List
            ? days
                  .whereType<String>()
                  .map((day) => day.toUpperCase())
                  .where(_byDayToken.hasMatch)
                  .toList()
            : const <String>[],
        byMonthDay: ints(decoded['byMonthDay']),
        byMonth: ints(decoded['byMonth']),
        bySetPos: ints(decoded['bySetPos']),
        rawRule: decoded['rawRule'] is String
            ? decoded['rawRule'] as String
            : null,
      );
    } on Object {
      return rule;
    }
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    DateTime? until,
    int? count,
    int? anchorDay,
    bool clearAnchorDay = false,
    List<DateTime>? excludedDates,
    bool clearUntil = false,
    bool clearCount = false,
    List<String>? byDay,
    List<int>? byMonthDay,
    List<int>? byMonth,
    List<int>? bySetPos,
    String? rawRule,
    bool clearDetails = false,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      until: clearUntil ? null : until ?? this.until,
      count: clearCount ? null : count ?? this.count,
      anchorDay: clearAnchorDay ? null : anchorDay ?? this.anchorDay,
      excludedDates: excludedDates ?? this.excludedDates,
      byDay: clearDetails ? const [] : byDay ?? this.byDay,
      byMonthDay: clearDetails ? const [] : byMonthDay ?? this.byMonthDay,
      byMonth: clearDetails ? const [] : byMonth ?? this.byMonth,
      bySetPos: clearDetails ? const [] : bySetPos ?? this.bySetPos,
      rawRule: clearDetails ? null : rawRule ?? this.rawRule,
    );
  }

  bool excludes(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return excludedDates.any(
      (excluded) =>
          excluded.year == target.year &&
          excluded.month == target.month &&
          excluded.day == target.day,
    );
  }
}
