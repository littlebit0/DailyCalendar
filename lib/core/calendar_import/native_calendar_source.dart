import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calendar_import_models.dart';

class NativeCalendarSource {
  NativeCalendarSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('daily/calendar_import');

  final MethodChannel _channel;

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  CalendarImportProvider? get provider => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => CalendarImportProvider.apple,
    TargetPlatform.android => CalendarImportProvider.samsung,
    _ => null,
  };

  Future<List<ImportableCalendar>> listCalendars() async {
    final sourceProvider = provider;
    if (!isSupported || sourceProvider == null) {
      return const [];
    }
    final values = await _channel.invokeListMethod<Object?>('listCalendars');
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((value) => _calendarFromMap(value, sourceProvider))
        .whereType<ImportableCalendar>()
        .toList(growable: false);
  }

  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async {
    final selected = calendars.toList(growable: false);
    if (!isSupported || selected.isEmpty) {
      return const [];
    }
    final sourceProvider = provider;
    if (sourceProvider == null) {
      return const [];
    }
    final values = await _channel.invokeListMethod<Object?>('loadEvents', {
      'calendarIds': selected.map((calendar) => calendar.id).toList(),
    });
    final calendarColors = {
      for (final calendar in selected) calendar.id: calendar.colorValue,
    };
    return (values ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (value) => _eventFromMap(
            value,
            sourceProvider,
            calendarColors[value['calendarId']],
          ),
        )
        .whereType<ExternalCalendarEvent>()
        .toList(growable: false);
  }

  ImportableCalendar? _calendarFromMap(
    Map<Object?, Object?> value,
    CalendarImportProvider provider,
  ) {
    final id = value['id'] as String?;
    final title = value['title'] as String?;
    if (id == null || id.isEmpty || title == null || title.trim().isEmpty) {
      return null;
    }
    return ImportableCalendar(
      id: id,
      title: title.trim(),
      provider: provider,
      accountName: value['accountName'] as String?,
      colorValue: (value['colorValue'] as num?)?.toInt(),
    );
  }

  ExternalCalendarEvent? _eventFromMap(
    Map<Object?, Object?> value,
    CalendarImportProvider provider,
    int? colorValue,
  ) {
    final sourceId = value['sourceId'] as String?;
    final calendarId = value['calendarId'] as String?;
    final startMilliseconds = (value['startMilliseconds'] as num?)?.toInt();
    final endMilliseconds = (value['endMilliseconds'] as num?)?.toInt();
    if (sourceId == null ||
        sourceId.isEmpty ||
        calendarId == null ||
        startMilliseconds == null ||
        endMilliseconds == null) {
      return null;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(startMilliseconds);
    var end = DateTime.fromMillisecondsSinceEpoch(endMilliseconds);
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    return ExternalCalendarEvent(
      sourceId: sourceId,
      calendarId: calendarId,
      provider: provider,
      title: ((value['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (value['title'] as String).trim()
          : '제목 없음',
      memo: value['memo'] as String?,
      location: value['location'] as String?,
      url: value['url'] as String?,
      startAt: start,
      endAt: end,
      allDay: value['allDay'] as bool? ?? false,
      recurrenceRule: value['recurrenceRule'] as String?,
      // Android sends the starts of removed or moved occurrences; Daily's
      // repeat rule excludes whole local days.
      excludedDates:
          (value['excludedMilliseconds'] as List<Object?>? ?? const [])
              .whereType<num>()
              .map((value) {
                final at = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return DateTime(at.year, at.month, at.day);
              })
              .toSet()
              .toList()
            ..sort(),
      colorValue: colorValue,
      reminderMinutesBeforeList:
          (value['reminderMinutesBeforeList'] as List<Object?>? ?? const [])
              .whereType<num>()
              .map((value) => value.toInt())
              .where((value) => value >= 0)
              .toSet()
              .toList()
            ..sort(),
    );
  }
}
