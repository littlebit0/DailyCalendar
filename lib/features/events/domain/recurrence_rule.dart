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
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime? until;
  final int? count;
  final int? anchorDay;
  final List<DateTime> excludedDates;

  bool get isRepeating => frequency != RecurrenceFrequency.none;

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
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      until: clearUntil ? null : until ?? this.until,
      count: clearCount ? null : count ?? this.count,
      anchorDay: clearAnchorDay ? null : anchorDay ?? this.anchorDay,
      excludedDates: excludedDates ?? this.excludedDates,
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
