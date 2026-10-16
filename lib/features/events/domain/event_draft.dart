import 'calendar_event.dart';
import 'event_category.dart';
import 'recurrence_rule.dart';

class EventDraft {
  EventDraft({
    required this.title,
    required this.startAt,
    required this.endAt,
    this.memo,
    this.location,
    this.url,
    this.weather,
    this.allDay = false,
    this.category = EventCategory.other,
    this.colorValue,
    this.categoryChanged = true,
    this.recurrenceCountChanged = false,
    int? reminderMinutesBefore = 60,
    List<int>? reminderMinutesBeforeList,
    this.recurrence = const RecurrenceRule(),
    this.showDday = false,
    this.alarmEnabled = false,
    int allDayAlarmMinutes = 9 * 60,
  }) : allDayAlarmMinutes = allDayAlarmMinutes.clamp(0, 1439),
       reminderMinutesBeforeList = normalizeReminderMinutes(
         reminderMinutesBeforeList ??
             (reminderMinutesBefore == null
                 ? const <int>[]
                 : <int>[reminderMinutesBefore]),
       );

  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final String? weather;
  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
  final EventCategory category;
  final int? colorValue;

  /// False when an editor saves without explicitly selecting a category.
  final bool categoryChanged;
  final bool recurrenceCountChanged;
  final List<int> reminderMinutesBeforeList;
  final RecurrenceRule recurrence;
  final bool showDday;
  final bool alarmEnabled;
  final int allDayAlarmMinutes;

  int? get reminderMinutesBefore => reminderMinutesBeforeList.isEmpty
      ? null
      : reminderMinutesBeforeList.first;

  CalendarEvent toEvent({
    required String id,
    required DateTime now,
    required String deviceId,
  }) {
    final resolvedColor = colorValue ?? category.colorValue;
    return CalendarEvent(
      id: id,
      title: title,
      memo: memo,
      location: location,
      url: url,
      weather: weather,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      category: category,
      colorValue: resolvedColor,
      reminderMinutesBeforeList: reminderMinutesBeforeList,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      syncStatus: 'pending',
      showDday: showDday,
      alarmEnabled: alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes,
      holiday: category.id == EventCategory.holiday.id,
    ).normalizeAllDayBounds();
  }

  CalendarEvent applyTo(CalendarEvent event) {
    return event.copyWith(
      title: title,
      memo: memo,
      location: location,
      url: url,
      weather: weather,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      category: category,
      colorValue: colorValue ?? category.colorValue,
      reminderMinutesBeforeList: reminderMinutesBeforeList,
      recurrence: recurrence,
      showDday: showDday,
      alarmEnabled: alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes,
      holiday: category.id == EventCategory.holiday.id,
      clearMemo: memo == null,
      clearLocation: location == null,
      clearUrl: url == null,
      clearWeather: weather == null,
      clearReminder: reminderMinutesBeforeList.isEmpty,
    );
  }

  EventDraft copyWith({
    String? title,
    String? memo,
    String? location,
    String? url,
    String? weather,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventCategory? category,
    int? colorValue,
    int? reminderMinutesBefore,
    List<int>? reminderMinutesBeforeList,
    RecurrenceRule? recurrence,
    bool? showDday,
    bool? alarmEnabled,
    int? allDayAlarmMinutes,
    bool clearMemo = false,
    bool clearLocation = false,
    bool clearUrl = false,
    bool clearWeather = false,
    bool clearReminder = false,
  }) {
    final nextReminderMinutes = clearReminder
        ? const <int>[]
        : reminderMinutesBeforeList ??
              (reminderMinutesBefore == null
                  ? this.reminderMinutesBeforeList
                  : <int>[reminderMinutesBefore]);
    return EventDraft(
      title: title ?? this.title,
      memo: clearMemo ? null : memo ?? this.memo,
      location: clearLocation ? null : location ?? this.location,
      url: clearUrl ? null : url ?? this.url,
      weather: clearWeather ? null : weather ?? this.weather,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      categoryChanged: categoryChanged,
      recurrenceCountChanged: recurrenceCountChanged,
      reminderMinutesBeforeList: nextReminderMinutes,
      recurrence: recurrence ?? this.recurrence,
      showDday: showDday ?? this.showDday,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes ?? this.allDayAlarmMinutes,
    );
  }
}
