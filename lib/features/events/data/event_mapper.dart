import 'dart:convert';

import '../../../core/sync/sync_version.dart';

import 'app_database.dart';
import '../domain/calendar_event.dart';
import '../domain/event_category.dart';
import '../domain/recurrence_rule.dart';

extension EventRecordMapper on EventRecord {
  CalendarEvent toDomain({DateTime? occurrenceStart}) {
    final baseStart = occurrenceStart ?? startAt;
    final duration = endAt.difference(startAt);
    final mappedCategory = EventCategory.fromStored(
      category,
      colorValue: colorValue,
    );
    final event = CalendarEvent(
      id: id,
      occurrenceId: occurrenceStart == null
          ? null
          : '$id@${occurrenceStart.toIso8601String()}',
      title: title,
      memo: memo,
      location: location,
      url: url,
      weather: weather,
      startAt: baseStart,
      endAt: baseStart.add(duration),
      allDay: allDay,
      category: mappedCategory,
      colorValue: colorValue,
      reminderMinutesBeforeList: _reminderMinutesFromJson(
        reminderMinutesBeforeList,
        reminderMinutesBefore,
      ),
      recurrence: RecurrenceRule(
        frequency: RecurrenceFrequency.fromName(recurrenceFrequency),
        interval: recurrenceInterval,
        until: recurrenceUntil,
        count: recurrenceCount,
        excludedDates: _excludedDatesFromJson(recurrenceExcludedDates),
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      deviceId: deviceId,
      syncStatus: syncStatus,
      showDday: showDday,
      completed: completed,
      alarmEnabled: alarmEnabled,
      allDayAlarmMinutes: allDayAlarmMinutes,
      holiday: mappedCategory.id == EventCategory.holiday.id,
    ).normalizeAllDayBounds();
    return restoreSyncTimestamps(event, syncTimestampDetails);
  }

  List<DateTime> _excludedDatesFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<String>()
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .map((date) => DateTime(date.year, date.month, date.day))
          .toList();
    } on Object {
      return const [];
    }
  }

  List<int> _reminderMinutesFromJson(String raw, int? legacyValue) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final values = normalizeReminderMinutes(decoded.whereType<int>());
        if (values.isNotEmpty || legacyValue == null) {
          return values;
        }
      }
    } on Object {
      // Fall back to the legacy single reminder column below.
    }
    return legacyValue == null
        ? const <int>[]
        : normalizeReminderMinutes([legacyValue]);
  }
}
