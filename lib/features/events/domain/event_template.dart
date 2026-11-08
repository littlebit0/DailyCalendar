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
/// alarm, all-day alarm time and alarm trigger (N minutes before, or a custom
/// alarm time kept as the same wall-clock time and day offset from the start
/// day, e.g. "the day before at 21:00") and whether an overnight event is
/// also listed on the following days. Never copied: event id, account/LMS source,
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
    this.endDayOffset = 0,
    int endMinutes = 10 * 60,
    required this.categoryId,
    List<int> reminderMinutesBeforeList = const [],
    this.showDday = false,
    this.alarmEnabled = false,
    int allDayAlarmMinutes = 9 * 60,
    int alarmMinutesBefore = 0,
    this.alarmCustomDayOffset,
    int? alarmCustomMinutes,
    this.favorite = false,
    this.showOvernightOnFollowingDays = true,
  }) : startMinutes = allDay ? 0 : startMinutes.clamp(0, 1439),
       endMinutes = allDay ? 0 : endMinutes.clamp(0, 1439),
       allDayAlarmMinutes = allDayAlarmMinutes.clamp(0, 1439),
       alarmMinutesBefore = alarmMinutesBefore < 0 ? 0 : alarmMinutesBefore,
       alarmCustomMinutes = alarmCustomMinutes?.clamp(0, 1439),
       reminderMinutesBeforeList = normalizeReminderMinutes(
         reminderMinutesBeforeList,
       );

  /// Upper bound for spans; longer drafts are refused (never shortened) and
  /// corrupt synced values are rejected by [isValid].
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

  /// Same meaning as [CalendarEvent.alarmMinutesBefore]; 0 = 정시.
  final int alarmMinutesBefore;

  /// A custom alarm time as days from the start day (negative = before) and
  /// minutes after midnight. Both null = no custom time; it overrides
  /// [alarmMinutesBefore] like [CalendarEvent.alarmCustomAt].
  final int? alarmCustomDayOffset;
  final int? alarmCustomMinutes;
  final bool favorite;
  final bool showOvernightOnFollowingDays;

  bool get _hasCustomAlarm =>
      alarmCustomDayOffset != null && alarmCustomMinutes != null;

  bool get isValid =>
      id.isNotEmpty &&
      name.trim().isNotEmpty &&
      title.trim().isNotEmpty &&
      categoryId.isNotEmpty &&
      endDayOffset >= 0 &&
      endDayOffset <= maxDaySpan &&
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
    // All-day drafts use an exclusive end date; step back one calendar day
    // (not 24 hours, which lands on the wrong date across a DST change).
    final endAt = draft.endAt;
    final endDay = draft.allDay
        ? DateTime(endAt.year, endAt.month, endAt.day - 1)
        : DateTime(endAt.year, endAt.month, endAt.day);
    final customAt = draft.alarmCustomAt;
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
      alarmMinutesBefore: draft.alarmMinutesBefore,
      alarmCustomDayOffset: customAt == null
          ? null
          : _calendarDaysBetween(startDay, customAt),
      alarmCustomMinutes: customAt == null
          ? null
          : customAt.hour * 60 + customAt.minute,
      favorite: favorite,
      showOvernightOnFollowingDays: draft.showOvernightOnFollowingDays,
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
      alarmMinutesBefore: alarmMinutesBefore,
      alarmCustomAt: _hasCustomAlarm
          ? DateTime(
              date.year,
              date.month,
              date.day + alarmCustomDayOffset!,
              alarmCustomMinutes! ~/ 60,
              alarmCustomMinutes! % 60,
            )
          : null,
      showOvernightOnFollowingDays: showOvernightOnFollowingDays,
    );
  }

  /// [draftOn], or null when a timed template's wall-clock times fall into a
  /// DST gap on [date] and DateTime's shift would invert the interval.
  EventDraft? validDraftOn(DateTime date, EventCategory category) {
    final draft = draftOn(date, category);
    return draft.allDay || draft.endAt.isAfter(draft.startAt) ? draft : null;
  }

  /// The first day from [from] on which this template's wall-clock times
  /// (including a custom alarm time) all exist, so editing it never rewrites
  /// them through a DST gap.
  DateTime representableDayFrom(DateTime from) {
    var day = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < 7 && !_keepsTimesOn(day); i++) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  bool _keepsTimesOn(DateTime day) {
    final draft = draftOn(day, EventCategory.basic);
    final customAt = draft.alarmCustomAt;
    if (customAt != null &&
        (customAt.hour * 60 + customAt.minute != alarmCustomMinutes ||
            _calendarDaysBetween(day, customAt) != alarmCustomDayOffset)) {
      return false;
    }
    if (allDay) return true;
    return draft.startAt.hour * 60 + draft.startAt.minute == startMinutes &&
        draft.endAt.hour * 60 + draft.endAt.minute == endMinutes;
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
    alarmMinutesBefore: alarmMinutesBefore,
    alarmCustomDayOffset: alarmCustomDayOffset,
    alarmCustomMinutes: alarmCustomMinutes,
    favorite: favorite ?? this.favorite,
    showOvernightOnFollowingDays: showOvernightOnFollowingDays,
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
    // Optional keys: absent means 정시, which older documents and apps assume.
    if (alarmMinutesBefore != 0) 'alarmMinutesBefore': alarmMinutesBefore,
    if (_hasCustomAlarm) ...{
      'alarmCustomDayOffset': alarmCustomDayOffset,
      'alarmCustomMinutes': alarmCustomMinutes,
    },
    'favorite': favorite,
    // Optional key: absent means on, which older documents and apps assume.
    if (!showOvernightOnFollowingDays) 'showOvernightOnFollowingDays': false,
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
        alarmMinutesBefore: json['alarmMinutesBefore'] as int? ?? 0,
        alarmCustomDayOffset: json['alarmCustomDayOffset'] as int?,
        alarmCustomMinutes: json['alarmCustomMinutes'] as int?,
        favorite: json['favorite'] as bool? ?? false,
        showOvernightOnFollowingDays:
            json['showOvernightOnFollowingDays'] as bool? ?? true,
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
