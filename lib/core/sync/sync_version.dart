import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';

String canonicalSyncJson(Object? value) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(canonical(value));
}

DateTime eventChangedAt(CalendarEvent event) {
  var latest = event.createdAt;
  if (event.updatedAt.isAfter(latest)) latest = event.updatedAt;
  if (event.deletedAt?.isAfter(latest) ?? false) latest = event.deletedAt!;
  return latest.toUtc();
}

/// Uses only persisted event values, never upload time or pending/synced state.
int compareEventVersions(CalendarEvent left, CalendarEvent right) {
  final time = eventChangedAt(left).compareTo(eventChangedAt(right));
  if (time != 0) return time;
  final deletion = (left.isDeleted ? 1 : 0).compareTo(right.isDeleted ? 1 : 0);
  if (deletion != 0) return deletion;
  // An older client may omit the extension. Equal-time metadata must survive.
  final source = (left.lms != null ? 1 : 0).compareTo(
    right.lms != null ? 1 : 0,
  );
  if (source != 0) return source;
  // Older writers can retain LMS metadata but omit the personal extension.
  // Preserve explicit completion at identical revisions; newer edits still win.
  final manual = (left.lms?.manuallyCompleted == true ? 1 : 0).compareTo(
    right.lms?.manuallyCompleted == true ? 1 : 0,
  );
  if (manual != 0) return manual;
  return canonicalSyncJson(
    eventVersionValues(left),
  ).compareTo(canonicalSyncJson(eventVersionValues(right)));
}

Map<String, Object?> eventVersionValues(CalendarEvent event) => {
  'id': event.id,
  'title': event.title,
  'memo': event.memo,
  'location': event.location,
  'url': event.url,
  'weather': event.weather,
  if (event.lms != null) 'lms': event.lms!.toJson(),
  'startAt': event.allDay
      ? _day(event.startAt)
      : event.startAt.toUtc().toIso8601String(),
  'endAt': event.allDay
      ? _day(event.endAt)
      : event.endAt.toUtc().toIso8601String(),
  'allDay': event.allDay,
  // Keep legacy label-based fingerprints compatible with existing precision data.
  // SQLite now stores stable IDs with categoryIdentity in its local extension.
  'category': event.category.id == 'basic' || event.category.id == 'holiday'
      ? event.category.id
      : event.category.label,
  'colorValue': event.colorValue,
  'reminders': event.reminderMinutesBeforeList,
  'frequency': event.recurrence.frequency.name,
  'interval': event.recurrence.interval,
  'until': event.recurrence.until == null
      ? null
      : _day(event.recurrence.until!),
  'count': event.recurrence.count,
  if (event.recurrence.anchorDay != null)
    'anchorDay': event.recurrence.anchorDay,
  if (event.recurrence.detailsJson != null)
    'details': event.recurrence.detailsJson,
  'excluded': event.recurrence.excludedDates.map(_day).toList()..sort(),
  'createdAt': event.createdAt.toUtc().toIso8601String(),
  'updatedAt': event.updatedAt.toUtc().toIso8601String(),
  'deletedAt': event.deletedAt?.toUtc().toIso8601String(),
  'deviceId': event.deviceId,
  'showDday': event.showDday,
  'completed': event.completed,
  'alarmEnabled': event.alarmEnabled,
  'allDayAlarmMinutes': event.allDayAlarmMinutes,
};

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _timestampFingerprint(CalendarEvent event) {
  final values = eventVersionValues(event);
  for (final key in ['createdAt', 'updatedAt', 'deletedAt']) {
    final value = values[key] as String?;
    values[key] = value == null
        ? null
        : DateTime.parse(value).millisecondsSinceEpoch ~/ 1000;
  }
  return sha256.convert(utf8.encode(canonicalSyncJson(values))).toString();
}

String encodeSyncTimestamps(CalendarEvent event) => jsonEncode({
  'categoryIdentity': event.category.toJson(),
  'fingerprint': _timestampFingerprint(event),
  'createdAt': event.createdAt.toUtc().toIso8601String(),
  'updatedAt': event.updatedAt.toUtc().toIso8601String(),
  'deletedAt': event.deletedAt?.toUtc().toIso8601String(),
});

CalendarEvent restoreSyncTimestamps(
  CalendarEvent event,
  String? details, {
  String? storedCategory,
}) {
  if (details == null) return event;
  final data = jsonDecode(details) as Map<String, dynamic>;
  final identity = data['categoryIdentity'];
  if (identity is Map &&
      (storedCategory == identity['id'] ||
          (storedCategory != 'basic' &&
              storedCategory != 'holiday' &&
              storedCategory == identity['label']))) {
    event = event.copyWith(
      category: EventCategory.fromJson(Map<String, Object?>.from(identity)),
    );
  }
  // Native/older writers do not update this column: never reuse stale precision.
  if (data['fingerprint'] != _timestampFingerprint(event)) return event;
  return event.copyWith(
    createdAt: DateTime.parse(data['createdAt'] as String),
    updatedAt: DateTime.parse(data['updatedAt'] as String),
    deletedAt: data['deletedAt'] == null
        ? null
        : DateTime.parse(data['deletedAt'] as String),
  );
}
