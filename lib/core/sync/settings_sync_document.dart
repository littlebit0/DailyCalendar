import '../settings/app_settings.dart';
import 'sync_version.dart';

/// LWW registers per scalar setting, category property, visibility and day order.
/// Null timestamps are legacy values, not fabricated migration/upload times.
class SettingsSyncValue {
  const SettingsSyncValue(this.value, this.changedAt, this.deviceId);
  final Object? value;
  final DateTime? changedAt;
  final String deviceId;

  int compareTo(SettingsSyncValue other) {
    final time = (changedAt?.microsecondsSinceEpoch ?? 0).compareTo(
      other.changedAt?.microsecondsSinceEpoch ?? 0,
    );
    if (time != 0) return time;
    final writer = deviceId.compareTo(other.deviceId);
    if (writer != 0) return writer;
    return canonicalSyncJson(value).compareTo(canonicalSyncJson(other.value));
  }

  Map<String, Object?> toJson() => {
    'value': value,
    'changedAt': changedAt?.toUtc().toIso8601String(),
    'deviceId': deviceId,
  };

  factory SettingsSyncValue.fromJson(Map<String, Object?> json) {
    final raw = json['changedAt'];
    final date = raw == null ? null : DateTime.tryParse(raw as String);
    if (raw != null && date == null) {
      throw const FormatException('Invalid setting revision');
    }
    return SettingsSyncValue(
      json['value'],
      date?.toUtc(),
      json['deviceId'] as String? ?? '',
    );
  }
}

class SettingsSyncDocument {
  const SettingsSyncDocument([this.fields = const {}]);
  final Map<String, SettingsSyncValue> fields;

  factory SettingsSyncDocument.fromJson(Map<String, Object?> json) =>
      SettingsSyncDocument(
        json.map(
          (key, value) => MapEntry(
            key,
            SettingsSyncValue.fromJson(Map<String, Object?>.from(value as Map)),
          ),
        ),
      );

  factory SettingsSyncDocument.legacy(Map<String, Object?> values) =>
      SettingsSyncDocument(
        flattenSyncSettings(values).map(
          (key, value) => MapEntry(key, SettingsSyncValue(value, null, '')),
        ),
      );

  Map<String, Object?> toJson() =>
      fields.map((key, value) => MapEntry(key, value.toJson()));

  SettingsSyncDocument merge(SettingsSyncDocument remote) {
    final merged = Map<String, SettingsSyncValue>.from(fields);
    for (final entry in remote.fields.entries) {
      final local = merged[entry.key];
      if (local == null || entry.value.compareTo(local) > 0) {
        merged[entry.key] = entry.value;
      }
    }
    return SettingsSyncDocument(merged);
  }

  SettingsSyncDocument recordChanges({
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required DateTime changedAt,
    required String deviceId,
  }) {
    final old = flattenSyncSettings(before);
    final next = flattenSyncSettings(after);
    final updated = Map<String, SettingsSyncValue>.from(fields);
    for (final key in {...old.keys, ...next.keys}) {
      if (canonicalSyncJson(old[key]) == canonicalSyncJson(next[key])) continue;
      updated[key] = SettingsSyncValue(next[key], changedAt.toUtc(), deviceId);
    }
    return SettingsSyncDocument(updated);
  }

  Map<String, Object?> values(Map<String, Object?> fallback) {
    final flat = flattenSyncSettings(fallback);
    for (final entry in fields.entries) {
      flat[entry.key] = entry.value.value;
    }
    return expandSyncSettings(flat);
  }

  bool sameAs(SettingsSyncDocument other) =>
      canonicalSyncJson(toJson()) == canonicalSyncJson(other.toJson());
}

Map<String, Object?> flattenSyncSettings(Map<String, Object?> settings) {
  final result = Map<String, Object?>.from(settings)
    ..remove('categories')
    ..remove('hiddenCategoryIds')
    ..remove('calendarManualEventOrders');
  final categories = settings['categories'];
  if (categories is List) {
    result['categoryOrder'] = [
      for (final category in categories) (category as Map)['id'],
    ];
    for (final item in categories) {
      final category = Map<String, Object?>.from(item as Map);
      final prefix =
          'category/${Uri.encodeComponent(category['id'] as String)}';
      result['$prefix/present'] = true;
      for (final entry in category.entries) {
        if (entry.key != 'id') result['$prefix/${entry.key}'] = entry.value;
      }
    }
  }
  for (final id in (settings['hiddenCategoryIds'] as List? ?? const [])) {
    result['hidden/${Uri.encodeComponent(id as String)}'] = true;
  }
  final orders = settings['calendarManualEventOrders'];
  if (orders is Map) {
    for (final entry in orders.entries) {
      result['order/${entry.key}'] = entry.value;
    }
  }
  return result;
}

Map<String, Object?> expandSyncSettings(Map<String, Object?> flat) {
  final result = <String, Object?>{};
  final categories = <String, Map<String, Object?>>{};
  final absent = <String>{};
  final hidden = <String>[];
  final orders = <String, Object?>{};
  for (final entry in flat.entries) {
    final parts = entry.key.split('/');
    if (parts.first == 'category' && parts.length == 3) {
      final id = Uri.decodeComponent(parts[1]);
      if (parts[2] == 'present') {
        if (entry.value != true) absent.add(id);
      } else if (entry.value != null) {
        (categories[id] ??= {'id': id})[parts[2]] = entry.value;
      }
    } else if (parts.first == 'hidden' && parts.length == 2) {
      if (entry.value == true) hidden.add(Uri.decodeComponent(parts[1]));
    } else if (parts.first == 'order' && parts.length == 2) {
      if (entry.value != null) orders[parts[1]] = entry.value;
    } else if (entry.key != 'categoryOrder' && entry.value != null) {
      result[entry.key] = entry.value;
    }
  }
  final order = (flat['categoryOrder'] as List? ?? const []).cast<String>();
  final ids = categories.keys.where((id) => !absent.contains(id)).toList()
    ..sort((a, b) {
      final ai = order.indexOf(a), bi = order.indexOf(b);
      if (ai < 0 && bi < 0) return a.compareTo(b);
      if (ai < 0) return 1;
      if (bi < 0) return -1;
      return ai.compareTo(bi);
    });
  result['categories'] = [for (final id in ids) categories[id]];
  result['hiddenCategoryIds'] = hidden..sort();
  result['calendarManualEventOrders'] = orders;
  return result;
}

Map<String, Object?> syncSettingsValues(AppSettings settings) => {
  'defaultReminderMinutes': settings.defaultReminderMinutes,
  'defaultReminderMinutesList': settings.defaultReminderMinutesList,
  'allDayReminderHour': settings.allDayReminderHour,
  'allDayReminderMinute': settings.allDayReminderMinute,
  'morningBriefingHour': settings.morningBriefingHour,
  'morningBriefingMinute': settings.morningBriefingMinute,
  'morningBriefingEnabled': settings.morningBriefingEnabled,
  'weekStartsOnMonday': settings.weekStartsOnMonday,
  'showLunarDates': settings.showLunarDates,
  'showAdjacentMonthDates': settings.showAdjacentMonthDates,
  'aiEnabled': settings.aiEnabled,
  'aiOnlyForComplexInput': settings.aiOnlyForComplexInput,
  'blockSensitiveAi': settings.blockSensitiveAi,
  'categories': settings.categories
      .map((category) => category.toJson())
      .toList(),
  'dDayReminderOffsets': settings.dDayReminderOffsets,
  'appTextSize': settings.appTextSize.name,
  'appStartView': settings.appStartView.name,
  'defaultCalendarView': settings.defaultCalendarView.name,
  'weekDayLayoutMode': settings.weekDayLayoutMode.name,
  'calendarEventTitleAlignment': settings.calendarEventTitleAlignment.name,
  'calendarEventSortPriority': settings.calendarEventSortPriority.name,
  'calendarManualEventOrders': settings.calendarManualEventOrders.map(
    (date, order) => MapEntry(date, order.toJson()),
  ),
  'hiddenCategoryIds': settings.hiddenCategoryIds,
  'calendarShowHolidays': settings.calendarShowHolidays,
  'calendarHolidayBackgroundEnabled': settings.calendarHolidayBackgroundEnabled,
  'calendarDdayOnly': settings.calendarDdayOnly,
  'use24HourTime': settings.use24HourTime,
  'themeMode': settings.themeMode.name,
  'monthNavigationMode': settings.monthNavigationMode.name,
};
