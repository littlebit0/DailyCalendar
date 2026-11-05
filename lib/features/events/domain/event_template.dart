import 'calendar_event.dart';
import 'event_category.dart';
import 'event_draft.dart';

/// A reusable, single (non-repeating) event preset.
///
/// Times are stored as wall-clock values relative to the day the template is
/// applied to, so 19:00–20:00 stays 19:00–20:00 across DST changes and a
/// template never carries an absolute date that could recreate a past event.
///
/// Copied into a new event: title, memo, location, URL, all-day flag, start
/// time, end day offset and end time, category, reminders, D-day display,
/// alarm and all-day alarm time. Never copied: event id, account/LMS source,
/// creation history, completion state, weather (date-specific) and recurrence.
class EventTemplate {
  EventTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.memo,
    this.location,
    this.url,
    this.allDay = false,
    int startMinutes = 9 * 60,
    int endDayOffset = 0,
    int endMinutes = 10 * 60,
    required this.categoryId,
    List<int> reminderMinutesBeforeList = const [],
    this.showDday = false,
    this.alarmEnabled = false,
    int allDayAlarmMinutes = 9 * 60,
    this.favorite = false,
  }) : startMinutes = allDay ? 0 : startMinutes.clamp(0, 1439),
       endDayOffset = endDayOffset.clamp(0, maxDaySpan),
       endMinutes = allDay ? 0 : endMinutes.clamp(0, 1439),
       allDayAlarmMinutes = allDayAlarmMinutes.clamp(0, 1439),
       reminderMinutesBeforeList = normalizeReminderMinutes(
         reminderMinutesBeforeList,
       );

  /// Upper bound for stored spans; protects against corrupt synced values.
  static const maxDaySpan = 366;

  final String id;
  final String name;
  final String title;
  final String? memo;
  final String? location;
  final String? url;
  final bool allDay;

  /// Minutes after midnight of the target day. Zero for all-day templates.
  final int startMinutes;

  /// Timed: days between start and end day (1 = ends after midnight).
  /// All-day: number of extra days after the first (0 = a single day).
  final int endDayOffset;

  /// Minutes after midnight of the end day. Zero for all-day templates.
  final int endMinutes;
  final String categoryId;
  final List<int> reminderMinutesBeforeList;
  final bool showDday;
  final bool alarmEnabled;
  final int allDayAlarmMinutes;
  final bool favorite;

  bool get isValid =>
      id.isNotEmpty &&
      name.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      categoryId.isNotEmpty &&
      (allDay || endDayOffset > 0 || endMinutes > startMinutes);

  /// Builds a template from an editor draft. Dates are reduced to offsets
  /// relative to the draft's start day; recurrence is intentionally dropped.
  factory EventTemplate.fromDraft(
    EventDraft draft, {
    required String id,
    required String name,
    bool favorite = false,
  }) {
    final startDay = DateTime(
      draft.startAt.year,
      draft.startAt.month,
      draft.startAt.day,
    );
    // All-day drafts use an exclusive end date.
    final lastMoment = draft.allDay
        ? draft.endAt.subtract(const Duration(days: 1))
        : draft.endAt;
    final endDay = DateTime(lastMoment.year, lastMoment.month, lastMoment.day);
    return EventTemplate(
      id: id,
      name: name.trim(),
      title: draft.title.trim(),
      memo: draft.memo,
      location: draft.location,
      url: draft.url,
      allDay: draft.allDay,
      startMinutes: draft.startAt.hour * 60 + draft.startAt.minute,
      endDayOffset: _calendarDaysBetween(startDay, endDay),
      endMinutes: draft.endAt.hour * 60 + draft.endAt.minute,
      categoryId: draft.category.id,
      reminderMinutesBeforeList: draft.reminderMinutesBeforeList,
      showDday: draft.showDday,
      alarmEnabled: draft.alarmEnabled,
      allDayAlarmMinutes: draft.allDayAlarmMinutes,
      favorite: favorite,
    );
  }

  /// A new single-event draft on [date] (only its calendar day is used).
  /// Local-time constructors keep wall-clock times across DST boundaries.
  EventDraft draftOn(DateTime date, EventCategory category) {
    final DateTime startAt;
    final DateTime endAt;
    if (allDay) {
      startAt = DateTime(date.year, date.month, date.day);
      endAt = DateTime(date.year, date.month, date.day + endDayOffset + 1);
    } else {
      startAt = DateTime(
        date.year,
        date.month,
        date.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );
      endAt = DateTime(
        date.year,
        date.month,
        date.day + endDayOffset,
        endMinutes ~/ 60,
        endMinutes % 60,
      );
    }
    return EventDraft(
      title: title,
      memo: memo,
      location: location,
      url: url,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      category: category,
      colorValue: category.colorValue,
      reminderMinutesBeforeList: reminderMinutesBeforeList,
      showDday: showDday,
      alarmEnabled: alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes,
    );
  }

  EventTemplate copyWith({String? name, bool? favorite}) => EventTemplate(
    id: id,
    name: name ?? this.name,
    title: title,
    memo: memo,
    location: location,
    url: url,
    allDay: allDay,
    startMinutes: startMinutes,
    endDayOffset: endDayOffset,
    endMinutes: endMinutes,
    categoryId: categoryId,
    reminderMinutesBeforeList: reminderMinutesBeforeList,
    showDday: showDday,
    alarmEnabled: alarmEnabled,
    allDayAlarmMinutes: allDayAlarmMinutes,
    favorite: favorite ?? this.favorite,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'title': title,
    if (memo != null) 'memo': memo,
    if (location != null) 'location': location,
    if (url != null) 'url': url,
    'allDay': allDay,
    'startMinutes': startMinutes,
    'endDayOffset': endDayOffset,
    'endMinutes': endMinutes,
    'categoryId': categoryId,
    'reminderMinutesBeforeList': reminderMinutesBeforeList,
    'showDday': showDday,
    'alarmEnabled': alarmEnabled,
    'allDayAlarmMinutes': allDayAlarmMinutes,
    'favorite': favorite,
  };

  /// Returns null for unreadable or invalid data instead of guessing values.
  static EventTemplate? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, Object?>.from(raw);
      final template = EventTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        title: json['title'] as String,
        memo: json['memo'] as String?,
        location: json['location'] as String?,
        url: json['url'] as String?,
        allDay: json['allDay'] as bool? ?? false,
        startMinutes: json['startMinutes'] as int? ?? 0,
        endDayOffset: json['endDayOffset'] as int? ?? 0,
        endMinutes: json['endMinutes'] as int? ?? 0,
        categoryId: json['categoryId'] as String,
        reminderMinutesBeforeList:
            (json['reminderMinutesBeforeList'] as List? ?? const [])
                .whereType<int>()
                .toList(),
        showDday: json['showDday'] as bool? ?? false,
        alarmEnabled: json['alarmEnabled'] as bool? ?? false,
        allDayAlarmMinutes: json['allDayAlarmMinutes'] as int? ?? 9 * 60,
        favorite: json['favorite'] as bool? ?? false,
      );
      return template.isValid ? template : null;
    } on Object {
      return null;
    }
  }
}

int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
