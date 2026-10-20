import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/events/data/recurrence_expander.dart';
import '../../features/events/domain/calendar_event.dart';
import '../../features/events/domain/event_category.dart';
import '../calendar/calendar_event_movement.dart';
import '../sync/google_drive_auth_service.dart';
import 'calendar_import_models.dart';
import 'calendar_import_service.dart';

class GoogleCalendarSource {
  GoogleCalendarSource({
    required GoogleDriveAuthService authService,
    http.Client? httpClient,
  }) : _authService = authService,
       _httpClient = httpClient ?? http.Client();

  static const _scope = GoogleDriveAuthService.calendarReadonlyScope;

  final GoogleDriveAuthService _authService;
  final http.Client _httpClient;

  Future<List<ImportableCalendar>> listCalendars() async {
    late Map<String, String> headers;
    try {
      headers = await _headers(promptIfNecessary: false);
    } on CalendarImportException {
      headers = await _headers(promptIfNecessary: true);
    }
    var response = await _getCalendarList(headers);
    if (_needsAdditionalAuthorization(response)) {
      headers = await _headers(promptIfNecessary: true);
      response = await _getCalendarList(headers);
    }
    _ensureSuccess(response);

    final calendars = <ImportableCalendar>[];
    String? pageToken;
    do {
      final pageResponse = pageToken == null
          ? response
          : await _getCalendarList(headers, pageToken: pageToken);
      _ensureSuccess(pageResponse);
      final body = _jsonMap(pageResponse.body);
      for (final item in (body['items'] as List<Object?>? ?? const [])) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final id = item['id'] as String?;
        final title =
            item['summaryOverride'] as String? ?? item['summary'] as String?;
        if (id == null || id.isEmpty || title == null || title.trim().isEmpty) {
          continue;
        }
        calendars.add(
          ImportableCalendar(
            id: id,
            title: title.trim(),
            provider: CalendarImportProvider.google,
            accountName: item['primary'] == true
                ? _authService.currentAccount?.email
                : null,
            colorValue: _parseGoogleColor(item['backgroundColor'] as String?),
            defaultReminderMinutes: _googleReminderMinutes(
              item['defaultReminders'],
            ),
          ),
        );
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return calendars;
  }

  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async {
    final selected = calendars
        .where((calendar) => calendar.provider == CalendarImportProvider.google)
        .toList(growable: false);
    if (selected.isEmpty) {
      return const [];
    }
    late Map<String, String> headers;
    try {
      headers = await _headers(promptIfNecessary: false);
    } on CalendarImportException {
      headers = await _headers(promptIfNecessary: true);
    }
    final events = <ExternalCalendarEvent>[];
    for (final calendar in selected) {
      // Exceptions may arrive on any page, before or after their series, so the
      // whole calendar is read before series and exceptions are joined.
      final items = <Map<String, dynamic>>[];
      String? pageToken;
      do {
        var response = await _getEvents(
          calendar.id,
          headers,
          pageToken: pageToken,
        );
        if (_needsAdditionalAuthorization(response)) {
          headers = await _headers(promptIfNecessary: true);
          response = await _getEvents(
            calendar.id,
            headers,
            pageToken: pageToken,
          );
        }
        _ensureSuccess(response);
        final body = _jsonMap(response.body);
        items.addAll(
          (body['items'] as List<Object?>? ?? const [])
              .whereType<Map<String, dynamic>>(),
        );
        pageToken = body['nextPageToken'] as String?;
      } while (pageToken != null && pageToken.isNotEmpty);
      events.addAll(_eventsFromItems(calendar, items));
    }
    return events;
  }

  /// Joins recurring series with their exception instances. A cancelled
  /// instance removes its original occurrence; a moved or edited instance
  /// removes its original occurrence and is imported once as itself.
  List<ExternalCalendarEvent> _eventsFromItems(
    ImportableCalendar calendar,
    List<Map<String, dynamic>> items,
  ) {
    final removedBySeries = <String, Set<DateTime>>{};
    for (final item in items) {
      final seriesId = item['recurringEventId'] as String?;
      final original = _occurrenceDate(item['originalStartTime']);
      if (seriesId != null && original != null) {
        removedBySeries.putIfAbsent(seriesId, () => {}).add(original);
      }
    }
    final events = <ExternalCalendarEvent>[];
    for (final item in items) {
      // A cancelled single event, or a cancelled instance already applied above.
      if (item['status'] == 'cancelled') continue;
      final event = _eventFromJson(
        calendar,
        item,
        removedOccurrences: removedBySeries[item['id']] ?? const {},
      );
      if (event == null) continue;
      events.add(event);
      events.addAll(
        _extraOccurrences(item, event, removedBySeries[item['id']] ?? const {}),
      );
    }
    return events;
  }

  /// RDATE occurrences cannot be expressed by a Daily repeat rule, so each one
  /// is imported as a single event with the series' duration (or, for a
  /// PERIOD value, its own end). EXDATE and cancelled or moved instances take
  /// precedence, and dates the RRULE or an earlier RDATE already produces are
  /// imported once.
  Iterable<ExternalCalendarEvent> _extraOccurrences(
    Map<String, dynamic> json,
    ExternalCalendarEvent series,
    Set<DateTime> removedOccurrences,
  ) sync* {
    final lines = _recurrenceLines(json, 'RDATE');
    if (lines.isEmpty) return;
    final excluded = _excludedDates(json, removedOccurrences).toSet();
    final rule = CalendarImportService.recurrenceFromRrule(
      series.recurrenceRule,
    );
    final expandable = rule.isRepeating && rule.rawRule == null;
    final master = CalendarEvent(
      id: series.sourceId,
      title: series.title,
      startAt: series.startAt,
      endAt: series.endAt,
      allDay: series.allDay,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      recurrence: rule,
      createdAt: series.startAt,
      updatedAt: series.startAt,
    );
    final expander = RecurrenceExpander();
    final duration = series.endAt.difference(series.startAt);
    // All-day spans are counted in calendar days so a daylight-saving change
    // inside the master span cannot shorten or lengthen the copy.
    final daySpan = calendarDayDifference(series.endAt, series.startAt);
    final seen = <DateTime>{series.startAt};
    for (final line in lines) {
      for (final value in _icalValues(line)) {
        final slash = value.indexOf('/');
        final startText = slash < 0 ? value : value.substring(0, slash);
        final parsed = _icalDateTime(startText);
        if (parsed == null) continue;
        final start = series.allDay || startText.length == 8
            ? DateTime(
                parsed.year,
                parsed.month,
                parsed.day,
                series.allDay ? 0 : series.startAt.hour,
                series.allDay ? 0 : series.startAt.minute,
              )
            : parsed;
        final DateTime end;
        if (series.allDay) {
          end = shiftCalendarDateByDays(start, daySpan < 1 ? 1 : daySpan);
        } else if (slash >= 0) {
          final endText = value.substring(slash + 1);
          final length = _icalDuration(endText);
          final explicitEnd = length != null
              ? start.add(length)
              : _icalDateTime(endText);
          if (explicitEnd == null || !explicitEnd.isAfter(start)) continue;
          end = explicitEnd;
        } else {
          end = start.add(duration);
        }
        if (excluded.contains(DateTime(start.year, start.month, start.day))) {
          continue;
        }
        if (!seen.add(start)) continue;
        if (expandable &&
            expander
                .expand(master, start, start.add(const Duration(minutes: 1)))
                .any((occurrence) => occurrence.startAt == start)) {
          continue;
        }
        yield ExternalCalendarEvent(
          sourceId: '${series.sourceId}#rdate#$value',
          calendarId: series.calendarId,
          provider: series.provider,
          title: series.title,
          memo: series.memo,
          location: series.location,
          url: series.url,
          startAt: start,
          endAt: end,
          allDay: series.allDay,
          colorValue: series.colorValue,
          reminderMinutesBeforeList: series.reminderMinutesBeforeList,
        );
      }
    }
  }

  /// RFC 5545 DURATION such as `PT2H`, `P1D` or `P1W`.
  Duration? _icalDuration(String value) {
    final match = RegExp(
      r'^\+?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(value);
    if (match == null || value.endsWith('P') || value.endsWith('T')) {
      return null;
    }
    int part(int index) => int.parse(match[index] ?? '0');
    return Duration(
      days: part(1) * 7 + part(2),
      hours: part(3),
      minutes: part(4),
      seconds: part(5),
    );
  }

  List<String> _recurrenceLines(Map<String, dynamic> json, String name) => [
    for (final line
        in (json['recurrence'] as List<Object?>? ?? const [])
            .whereType<String>())
      if (line.toUpperCase().startsWith('$name:') ||
          line.toUpperCase().startsWith('$name;'))
        line,
  ];

  /// The comma-separated values after a property's parameters.
  List<String> _icalValues(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return const [];
    return [
      for (final value in line.substring(colon + 1).split(','))
        if (value.trim().isNotEmpty) value.trim(),
    ];
  }

  /// `YYYYMMDD`, `YYYYMMDDTHHMMSS` (floating or TZID time, read as written)
  /// or `...Z` (UTC, converted to local time).
  // shortcut: a TZID time is read as device-local time, so it can land on the
  // wrong date when the device is in another zone; convert by TZID when the
  // app gains a time-zone database.
  DateTime? _icalDateTime(String value) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?$',
    ).firstMatch(value);
    if (match == null) return null;
    int part(int index) => int.parse(match[index] ?? '0');
    if (match[4] == null) return DateTime(part(1), part(2), part(3));
    final utc = match[7] == 'Z';
    final values = [part(1), part(2), part(3), part(4), part(5), part(6)];
    return utc
        ? DateTime.utc(
            values[0],
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
          ).toLocal()
        : DateTime(
            values[0],
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
          );
  }

  /// The local date of an occurrence's original start (`originalStartTime`).
  DateTime? _occurrenceDate(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final allDay = value['date'] is String;
    final date = _googleDate(value, allDay: allDay);
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  Future<Map<String, String>> _headers({
    required bool promptIfNecessary,
  }) async {
    try {
      final headers = await _authService.authorizationHeadersForScopes(const [
        _scope,
      ], promptIfNecessary: promptIfNecessary);
      if (headers == null || headers.isEmpty) {
        throw const CalendarImportException('Google 계정 로그인이 필요합니다.');
      }
      return headers;
    } on GoogleDriveAuthException catch (error) {
      throw CalendarImportException(
        error.message.replaceAll('Google Drive', 'Google Calendar'),
      );
    }
  }

  Future<http.Response> _getCalendarList(
    Map<String, String> headers, {
    String? pageToken,
  }) {
    final query = <String, String>{'maxResults': '250'};
    if (pageToken != null) {
      query['pageToken'] = pageToken;
    }
    return _httpClient.get(
      Uri.https(
        'www.googleapis.com',
        '/calendar/v3/users/me/calendarList',
        query,
      ),
      headers: headers,
    );
  }

  Future<http.Response> _getEvents(
    String calendarId,
    Map<String, String> headers, {
    String? pageToken,
  }) {
    final query = <String, String>{
      'maxResults': '2500',
      'showDeleted': 'false',
      'singleEvents': 'false',
    };
    if (pageToken != null) {
      query['pageToken'] = pageToken;
    }
    return _httpClient.get(
      Uri(
        scheme: 'https',
        host: 'www.googleapis.com',
        pathSegments: ['calendar', 'v3', 'calendars', calendarId, 'events'],
        queryParameters: query,
      ),
      headers: headers,
    );
  }

  ExternalCalendarEvent? _eventFromJson(
    ImportableCalendar calendar,
    Map<String, dynamic> json, {
    Set<DateTime> removedOccurrences = const {},
  }) {
    final id = json['id'] as String?;
    final startValue = json['start'];
    final endValue = json['end'];
    if (id == null ||
        id.isEmpty ||
        startValue is! Map<String, dynamic> ||
        endValue is! Map<String, dynamic>) {
      return null;
    }
    final allDay = startValue['date'] is String;
    final start = _googleDate(startValue, allDay: allDay);
    final end = _googleDate(endValue, allDay: allDay);
    if (start == null || end == null) {
      return null;
    }
    final recurrenceValues = json['recurrence'] as List<Object?>?;
    final recurrenceRule = recurrenceValues?.whereType<String>().firstWhere(
      (value) => value.startsWith('RRULE:'),
      orElse: () => '',
    );
    return ExternalCalendarEvent(
      sourceId: id,
      calendarId: calendar.id,
      provider: CalendarImportProvider.google,
      title: ((json['summary'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['summary'] as String).trim()
          : '제목 없음',
      memo: json['description'] as String?,
      location: json['location'] as String?,
      url: json['htmlLink'] as String?,
      startAt: start,
      endAt: end.isAfter(start)
          ? end
          : start.add(
              allDay ? const Duration(days: 1) : const Duration(hours: 1),
            ),
      allDay: allDay,
      recurrenceRule: recurrenceRule == null || recurrenceRule.isEmpty
          ? null
          : recurrenceRule,
      excludedDates: recurrenceRule == null || recurrenceRule.isEmpty
          ? const []
          : _excludedDates(json, removedOccurrences),
      colorValue: calendar.colorValue,
      reminderMinutesBeforeList: _eventReminderMinutes(json, calendar),
    );
  }

  /// EXDATE values plus occurrences removed by cancelled or moved instances.
  List<DateTime> _excludedDates(
    Map<String, dynamic> json,
    Set<DateTime> removedOccurrences,
  ) {
    final dates = {...removedOccurrences};
    for (final line in _recurrenceLines(json, 'EXDATE')) {
      for (final value in _icalValues(line)) {
        final parsed = _icalDateTime(value);
        if (parsed != null) {
          dates.add(DateTime(parsed.year, parsed.month, parsed.day));
        }
      }
    }
    return dates.toList()..sort();
  }

  List<int> _eventReminderMinutes(
    Map<String, dynamic> json,
    ImportableCalendar calendar,
  ) {
    final reminders = json['reminders'];
    if (reminders is! Map<String, dynamic>) {
      return const [];
    }
    if (reminders['useDefault'] == true) {
      return calendar.defaultReminderMinutes;
    }
    return _googleReminderMinutes(reminders['overrides']);
  }

  List<int> _googleReminderMinutes(Object? value) {
    if (value is! List<Object?>) {
      return const [];
    }
    final minutes = <int>{};
    for (final item in value) {
      if (item is! Map<String, dynamic> || item['method'] != 'popup') {
        continue;
      }
      final minute = item['minutes'];
      if (minute is num && minute >= 0) {
        minutes.add(minute.toInt());
      }
    }
    final sorted = minutes.toList()..sort();
    return sorted;
  }

  DateTime? _googleDate(Map<String, dynamic> value, {required bool allDay}) {
    final raw = value[allDay ? 'date' : 'dateTime'] as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return allDay
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : parsed.toLocal();
  }

  bool _needsAdditionalAuthorization(http.Response response) =>
      response.statusCode == 401 || response.statusCode == 403;

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarImportException(
        'Google Calendar 데이터를 가져오지 못했습니다. (${response.statusCode})',
      );
    }
  }

  Map<String, dynamic> _jsonMap(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const CalendarImportException('Google Calendar 응답 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  int? _parseGoogleColor(String? value) {
    if (value == null || !value.startsWith('#')) {
      return null;
    }
    final rgb = int.tryParse(value.substring(1), radix: 16);
    return rgb == null ? null : 0xff000000 | rgb;
  }
}

class CalendarImportException implements Exception {
  const CalendarImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
