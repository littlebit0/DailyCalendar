import '../../../core/lms/lms_models.dart';
import 'event_category.dart';
import 'recurrence_rule.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.category,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.occurrenceId,
    this.memo,
    this.location,
    this.url,
    this.weather,
    this.lms,
    int? reminderMinutesBefore,
    List<int>? reminderMinutesBeforeList,
    this.recurrence = const RecurrenceRule(),
    this.deletedAt,
    this.deviceId = '',
    this.syncStatus = 'pending',
    this.showDday = false,
    this.completed = false,
    this.alarmEnabled = false,
    int allDayAlarmMinutes = 9 * 60,
    this.readOnly = false,
    this.systemEvent = false,
    this.holiday = false,
  }) : allDayAlarmMinutes = allDayAlarmMinutes.clamp(0, 1439),
       reminderMinutesBeforeList = normalizeReminderMinutes(
         reminderMinutesBeforeList ??
             (reminderMinutesBefore == null
                 ? const <int>[]
                 : <int>[reminderMinutesBefore]),
       );

  final String id;
  final String? occurrenceId;
  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final String? weather;
  final LmsEventMetadata? lms;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final EventCategory category;
  final int colorValue;
  final List<int> reminderMinutesBeforeList;
  final RecurrenceRule recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String syncStatus;
  final bool showDday;
  final bool completed;
  final bool alarmEnabled;
  final int allDayAlarmMinutes;
  final bool readOnly;
  final bool systemEvent;
  final bool holiday;

  Duration get duration => endAt.difference(startAt);

  bool get isDeleted => deletedAt != null;

  bool get isRecurring => recurrence.isRepeating;

  // A metadata-stripped LMS record from an older client is never a personal
  // event: retain it without exposing it to another account.
  bool isVisibleToOwner(String? googleEmail) =>
      lms == null ? !id.startsWith('lms:') : lms!.belongsToOwner(googleEmail);

  int? get reminderMinutesBefore => reminderMinutesBeforeList.isEmpty
      ? null
      : reminderMinutesBeforeList.first;

  CalendarEvent normalizeAllDayBounds() {
    if (!allDay) {
      return this;
    }
    final normalizedStart = DateTime(startAt.year, startAt.month, startAt.day);
    var normalizedEnd = DateTime(endAt.year, endAt.month, endAt.day);
    if (!normalizedEnd.isAfter(normalizedStart)) {
      normalizedEnd = normalizedStart.add(const Duration(days: 1));
    }
    if (normalizedStart == startAt && normalizedEnd == endAt) {
      return this;
    }
    return copyWith(startAt: normalizedStart, endAt: normalizedEnd);
  }

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    if (lms != null && startAt.isAtSameMomentAs(endAt)) {
      return !startAt.isBefore(rangeStart) && startAt.isBefore(rangeEnd);
    }
    return startAt.isBefore(rangeEnd) && endAt.isAfter(rangeStart);
  }

  CalendarEvent copyWith({
    String? id,
    String? occurrenceId,
    String? title,
    String? memo,
    String? location,
    String? url,
    String? weather,
    LmsEventMetadata? lms,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventCategory? category,
    int? colorValue,
    int? reminderMinutesBefore,
    List<int>? reminderMinutesBeforeList,
    RecurrenceRule? recurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deviceId,
    String? syncStatus,
    bool? showDday,
    bool? completed,
    bool? alarmEnabled,
    int? allDayAlarmMinutes,
    bool? readOnly,
    bool? systemEvent,
    bool? holiday,
    bool clearOccurrenceId = false,
    bool clearMemo = false,
    bool clearLocation = false,
    bool clearUrl = false,
    bool clearWeather = false,
    bool clearLms = false,
    bool clearReminder = false,
    bool clearDeletedAt = false,
  }) {
    final nextReminderMinutes = clearReminder
        ? const <int>[]
        : reminderMinutesBeforeList ??
              (reminderMinutesBefore == null
                  ? this.reminderMinutesBeforeList
                  : <int>[reminderMinutesBefore]);
    return CalendarEvent(
      id: id ?? this.id,
      occurrenceId: clearOccurrenceId
          ? null
          : occurrenceId ?? this.occurrenceId,
      title: title ?? this.title,
      memo: clearMemo ? null : memo ?? this.memo,
      location: clearLocation ? null : location ?? this.location,
      url: clearUrl ? null : url ?? this.url,
      weather: clearWeather ? null : weather ?? this.weather,
      lms: clearLms ? null : lms ?? this.lms,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      reminderMinutesBeforeList: nextReminderMinutes,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? this.syncStatus,
      showDday: showDday ?? this.showDday,
      completed: completed ?? this.completed,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes ?? this.allDayAlarmMinutes,
      readOnly: readOnly ?? this.readOnly,
      systemEvent: systemEvent ?? this.systemEvent,
      holiday: holiday ?? this.holiday,
    );
  }
}

List<int> normalizeReminderMinutes(Iterable<int> values) {
  final sorted = values.where((value) => value >= 0).toSet().toList()..sort();
  return List.unmodifiable(sorted);
}
