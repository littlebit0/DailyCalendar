import 'dart:convert';

import 'calendar_event.dart' show normalizeReminderMinutes;

/// The alarm triggers of one event: "N minutes before" offsets and absolute
/// custom times, plus the single legacy trigger written for older clients.
///
/// [minutesBefore]/[customAt] are the representative (earliest) trigger that
/// 4.1.0 and older read from `alarmMinutesBefore`/`alarmCustomAt`. When the
/// representative is a custom time, [minutesBefore] keeps the caller's legacy
/// value because older clients ignore it while a custom time is set.
typedef AlarmTriggers = ({
  int minutesBefore,
  DateTime? customAt,
  List<int> minutesList,
  List<DateTime> customList,
});

/// Reference for relative alarms: the start, or the all-day alarm clock time.
DateTime alarmBaseTimeFor(
  DateTime startAt,
  bool allDay,
  int allDayAlarmMinutes,
) => allDay
    ? DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        allDayAlarmMinutes ~/ 60,
        allDayAlarmMinutes % 60,
      )
    : startAt;

/// Builds [AlarmTriggers]. Without lists the legacy single trigger is the
/// whole set (a legacy custom time overrides its minutes, as before). An empty
/// selection falls back to 정시 so an enabled alarm always has a time.
AlarmTriggers resolveAlarmTriggers({
  required DateTime base,
  required int minutesBefore,
  required DateTime? customAt,
  List<int>? minutesList,
  List<DateTime>? customList,
}) {
  final legacyMinutes = minutesBefore < 0 ? 0 : minutesBefore;
  if (minutesList == null && customList == null) {
    return (
      minutesBefore: legacyMinutes,
      customAt: customAt,
      minutesList: customAt == null
          ? List<int>.unmodifiable([legacyMinutes])
          : const <int>[],
      customList: customAt == null
          ? const <DateTime>[]
          : List<DateTime>.unmodifiable([customAt]),
    );
  }
  var minutes = normalizeReminderMinutes(minutesList ?? const <int>[]);
  final customs = normalizeAlarmCustomTimes(customList ?? const <DateTime>[]);
  if (minutes.isEmpty && customs.isEmpty) minutes = const [0];
  final earliestRelative = minutes.isEmpty
      ? null
      : base.subtract(Duration(minutes: minutes.last));
  final customFirst =
      customs.isNotEmpty &&
      (earliestRelative == null || customs.first.isBefore(earliestRelative));
  return (
    minutesBefore: customFirst ? legacyMinutes : minutes.last,
    customAt: customFirst ? customs.first : null,
    minutesList: minutes,
    customList: customs,
  );
}

/// Sorted custom alarm times with duplicates (same instant) removed.
List<DateTime> normalizeAlarmCustomTimes(Iterable<DateTime> values) {
  final seen = <int>{};
  final sorted = [
    for (final value in values)
      if (seen.add(value.microsecondsSinceEpoch)) value,
  ]..sort();
  return List.unmodifiable(sorted);
}

/// Every fire time of [triggers], earliest first, each instant once.
List<DateTime> alarmFireTimesOf(AlarmTriggers triggers, DateTime base) =>
    normalizeAlarmCustomTimes([
      for (final minutes in triggers.minutesList)
        base.subtract(Duration(minutes: minutes)),
      ...triggers.customList,
    ]);

/// Whether an older client changed the legacy alarm fields without the lists
/// (a list-preserving client that edited only `alarmMinutesBefore` or
/// `alarmCustomAt`). Then the legacy value wins and the lists are dropped.
bool alarmListsContradictLegacy(
  AlarmTriggers fromLists, {
  required int legacyMinutes,
  required DateTime? legacyCustomAt,
}) {
  final custom = fromLists.customAt;
  if (custom != null) {
    // SQLite keeps the legacy column in whole seconds.
    return legacyCustomAt == null ||
        legacyCustomAt.millisecondsSinceEpoch ~/ 1000 !=
            custom.millisecondsSinceEpoch ~/ 1000;
  }
  return legacyCustomAt != null || legacyMinutes != fromLists.minutesBefore;
}

/// The stored alarm lists to use with the stored legacy fields: null (the
/// single legacy trigger) when absent, unreadable or contradicted by an older
/// client's legacy-only edit.
({List<int>? minutes, List<DateTime>? customs}) acceptedAlarmLists({
  required DateTime base,
  required int legacyMinutes,
  required DateTime? legacyCustomAt,
  required Object? minutes,
  required Object? customs,
}) {
  final minutesList = decodeAlarmMinutesList(minutes);
  final customList = decodeAlarmCustomList(customs);
  if (minutesList == null && customList == null) {
    return (minutes: null, customs: null);
  }
  final fromLists = resolveAlarmTriggers(
    base: base,
    minutesBefore: legacyMinutes,
    customAt: null,
    minutesList: minutesList,
    customList: customList,
  );
  if (alarmListsContradictLegacy(
    fromLists,
    legacyMinutes: legacyMinutes < 0 ? 0 : legacyMinutes,
    legacyCustomAt: legacyCustomAt,
  )) {
    return (minutes: null, customs: null);
  }
  return (minutes: minutesList, customs: customList);
}

/// A minutes list from a JSON list or a JSON-encoded string; null if invalid.
List<int>? decodeAlarmMinutesList(Object? raw) {
  final list = _jsonList(raw);
  if (list == null || list.any((value) => value is! int)) return null;
  return list.cast<int>();
}

/// Custom times from UTC ISO strings (a JSON list or a JSON-encoded string),
/// as local times; null if any entry is unreadable.
List<DateTime>? decodeAlarmCustomList(Object? raw) {
  final list = _jsonList(raw);
  if (list == null) return null;
  final values = <DateTime>[];
  for (final value in list) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) return null;
    values.add(parsed.toLocal());
  }
  return values;
}

List<String> encodeAlarmCustomList(List<DateTime> values) =>
    values.map((value) => value.toUtc().toIso8601String()).toList();

List<Object?>? _jsonList(Object? raw) {
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
  return raw is List ? raw : null;
}
