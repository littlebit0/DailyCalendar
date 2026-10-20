import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
    final removedBySeries = <String, _Exclusions>{};
    for (final item in items) {
      final seriesId = item['recurringEventId'] as String?;
      final original = item['originalStartTime'];
      if (seriesId != null && original is Map<String, dynamic>) {
        _addOriginalStart(
          removedBySeries.putIfAbsent(seriesId, _Exclusions.new),
          original,
        );
      }
    }
    final events = <ExternalCalendarEvent>[];
    for (final item in items) {
      // A cancelled single event, or a cancelled instance already applied above.
      if (item['status'] == 'cancelled') continue;
      final exclusions = _exclusionsOf(item, removedBySeries[item['id']]);
      var event = _eventFromJson(calendar, item, exclusions);
      if (event == null) continue;
      final rdates = _rdateOccurrences(item, event, exclusions);
      final repeats = _repeatsByRule(event);
      if (rdates.replacedDays.isNotEmpty && repeats) {
        exclusions.days.addAll(rdates.replacedDays);
        event = _eventFromJson(calendar, item, exclusions) ?? event;
      }
      // A master that Daily keeps as one plain event never consults the
      // exclusions, so an excluded or replaced DTSTART is dropped here.
      final dropMaster =
          !repeats &&
          (exclusions.excludes(event.startAt) || rdates.replacesMaster);
      if (!dropMaster) events.add(event);
      events.addAll(rdates.events);
    }
    return events;
  }

  bool _repeatsByRule(ExternalCalendarEvent event) {
    final rule = CalendarImportService.recurrenceFromRrule(
      event.recurrenceRule,
    );
    return rule.isRepeating && rule.rawRule == null;
  }

  /// `originalStartTime` of a cancelled or moved instance. An offsetless
  /// `dateTime` is read in its `timeZone`.
  void _addOriginalStart(_Exclusions target, Map<String, dynamic> value) {
    final date = value['date'];
    final dateTime = value['dateTime'];
    if (date is String) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        target.days.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    } else if (dateTime is String) {
      final parsed = DateTime.tryParse(dateTime);
      if (parsed == null) return;
      target.instants.add(
        _googleInstant(parsed, dateTime, value['timeZone'] as String?),
      );
    }
  }

  DateTime _toLocal(tz.TZDateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch);

  /// EXDATE values plus the originals of cancelled or moved instances.
  _Exclusions _exclusionsOf(Map<String, dynamic> json, _Exclusions? removed) {
    final result = _Exclusions();
    if (removed != null) {
      result.instants.addAll(removed.instants);
      result.days.addAll(removed.days);
    }
    for (final line in _recurrenceLines(json, 'EXDATE')) {
      final tzid = _icalTzid(line);
      for (final value in _icalValues(line)) {
        final parsed = _icalDateTime(value, tzid: tzid);
        if (parsed == null) continue;
        if (value.length == 8) {
          result.days.add(parsed);
        } else {
          result.instants.add(parsed);
        }
      }
    }
    return result;
  }

  /// RDATE occurrences cannot be expressed by a Daily repeat rule, so each one
  /// is imported as a single event with the series' duration (or, for a
  /// PERIOD value, its own). EXDATE and cancelled or moved instances take
  /// precedence by exact start. A start the RRULE or an earlier RDATE already
  /// produces is imported once, with the PERIOD's duration when it has one.
  _Rdates _rdateOccurrences(
    Map<String, dynamic> json,
    ExternalCalendarEvent series,
    _Exclusions exclusions,
  ) {
    final lines = _recurrenceLines(json, 'RDATE');
    if (lines.isEmpty) return const _Rdates();
    final rule = CalendarImportService.recurrenceFromRrule(
      series.recurrenceRule,
    );
    final expandable = _repeatsByRule(series);
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
    // Google expands the series in its own `start.timeZone`, so RDATEs are
    // compared with the series in that zone's wall-clock time.
    final sourceZone = _sourceZone(json);
    final axis = expandable && !series.allDay
        ? _WallAxis.of(sourceZone, master, series.recurrenceRule)
        : null;
    DateTime wall(DateTime instant) => _WallAxis.wallOf(sourceZone, instant);
    final wallMaster = axis?.wallMaster ?? master;
    final duration = series.endAt.difference(series.startAt);
    // All-day spans are counted in calendar days so a daylight-saving change
    // inside the master span cannot shorten or lengthen the copy.
    final daySpan = calendarDayDifference(series.endAt, series.startAt);
    final byStart = <DateTime, ExternalCalendarEvent>{};
    final replacedDays = <DateTime>{};
    var replacesMaster = false;
    for (final line in lines) {
      final tzid = _icalTzid(line);
      for (final value in _icalValues(line)) {
        final slash = value.indexOf('/');
        final startText = slash < 0 ? value : value.substring(0, slash);
        final parsed = _icalDateTime(startText, tzid: tzid);
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
        final hasPeriod = slash >= 0 && !series.allDay;
        final DateTime end;
        if (series.allDay) {
          end = shiftCalendarDateByDays(start, daySpan < 1 ? 1 : daySpan);
        } else if (hasPeriod) {
          final endText = value.substring(slash + 1);
          final length = _icalDuration(endText);
          final explicitEnd = length != null
              ? _addPeriod(startText, tzid, start, length)
              : _icalDateTime(endText, tzid: tzid);
          if (explicitEnd == null || !explicitEnd.isAfter(start)) continue;
          end = explicitEnd;
        } else {
          end = start.add(duration);
        }
        if (exclusions.excludes(start)) continue;
        if (byStart.containsKey(start)) {
          if (!hasPeriod) continue;
        } else {
          final startWall = wall(start);
          final isMaster = startWall == wall(series.startAt);
          final generated =
              isMaster ||
              (expandable &&
                  expander
                      .expand(
                        wallMaster,
                        startWall,
                        startWall.add(const Duration(minutes: 1)),
                      )
                      .any((occurrence) => occurrence.startAt == startWall));
          if (generated) {
            if (!hasPeriod) continue;
            // The PERIOD occurrence replaces the generated one.
            replacedDays.add(
              axis?.deviceDay(start) ??
                  DateTime(start.year, start.month, start.day),
            );
            replacesMaster = replacesMaster || isMaster;
          }
        }
        byStart[start] = ExternalCalendarEvent(
          sourceId:
              '${series.sourceId}#rdate#${tzid == null ? '' : '$tzid:'}$value',
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
    return _Rdates(
      events: byStart.values.toList(),
      replacedDays: replacedDays,
      replacesMaster: replacesMaster,
    );
  }

  /// [start] plus a duration whose days are nominal calendar days counted in
  /// the declared zone (not the device zone) before the exact time part.
  DateTime _addPeriod(
    String startText,
    String? tzid,
    DateTime start,
    ({int days, Duration time}) length,
  ) {
    final utc = startText.endsWith('Z');
    final location = utc ? null : _zone(tzid);
    final wall = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$',
    ).firstMatch(startText);
    if ((location == null && !utc) || wall == null) {
      return shiftCalendarDateByDays(start, length.days).add(length.time);
    }
    int part(int index) => int.parse(wall[index]!);
    if (utc) {
      return DateTime.utc(
        part(1),
        part(2),
        part(3) + length.days,
        part(4),
        part(5),
        part(6),
      ).add(length.time).toLocal();
    }
    return _toLocal(
      tz.TZDateTime(
        location!,
        part(1),
        part(2),
        part(3) + length.days,
        part(4),
        part(5),
        part(6),
      ).add(length.time),
    );
  }

  /// RFC 5545 DURATION such as `PT2H`, `P1D` or `P1W`. Day and week parts are
  /// nominal calendar days; only the time part is an exact length.
  ({int days, Duration time})? _icalDuration(String value) {
    final match = RegExp(
      r'^\+?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(value);
    if (match == null || value.endsWith('P') || value.endsWith('T')) {
      return null;
    }
    int part(int index) => int.parse(match[index] ?? '0');
    return (
      days: part(1) * 7 + part(2),
      time: Duration(hours: part(3), minutes: part(4), seconds: part(5)),
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

  /// The `TZID` parameter of a recurrence line, if any.
  String? _icalTzid(String line) {
    final colon = line.indexOf(':');
    final head = colon < 0 ? line : line.substring(0, colon);
    return RegExp(
      r';TZID=([^;:]+)',
      caseSensitive: false,
    ).firstMatch(head)?[1]?.replaceAll('"', '');
  }

  static bool _zonesReady = false;

  /// `YYYYMMDD`, `YYYYMMDDTHHMMSS` (read in [tzid] when it is a known zone,
  /// else as device-local floating time) or `...Z` (UTC); local time.
  DateTime? _icalDateTime(String value, {String? tzid}) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z?))?$',
    ).firstMatch(value);
    if (match == null) return null;
    int part(int index) => int.parse(match[index] ?? '0');
    if (match[4] == null) return DateTime(part(1), part(2), part(3));
    final values = [part(1), part(2), part(3), part(4), part(5), part(6)];
    if (match[7] == 'Z') {
      return DateTime.utc(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
      ).toLocal();
    }
    final location = _zone(tzid);
    if (location != null) {
      final zoned = tz.TZDateTime(
        location,
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
      );
      return _toLocal(zoned);
    }
    return DateTime(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
    );
  }

  tz.Location? _zone(String? tzid) {
    if (tzid == null) return null;
    if (!_zonesReady) {
      tz_data.initializeTimeZones();
      _zonesReady = true;
    }
    try {
      return tz.getLocation(tzid);
    } on tz.LocationNotFoundException {
      return null;
    }
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
    Map<String, dynamic> json,
    _Exclusions exclusions,
  ) {
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
    final endAt = end.isAfter(start)
        ? end
        : start.add(
            allDay ? const Duration(days: 1) : const Duration(hours: 1),
          );
    final repeats = recurrenceRule != null && recurrenceRule.isNotEmpty;
    // Exclusions must land on the dates Daily expands the stored series on.
    final axis = repeats && !allDay
        ? _WallAxis.of(
            _sourceZone(json),
            _masterOf(id, start, endAt, allDay, recurrenceRule),
            recurrenceRule,
          )
        : null;
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
      endAt: endAt,
      allDay: allDay,
      recurrenceRule: repeats ? recurrenceRule : null,
      excludedDates: repeats ? exclusions.ruleDates(axis?.deviceDay) : const [],
      colorValue: calendar.colorValue,
      reminderMinutesBeforeList: _eventReminderMinutes(json, calendar),
    );
  }

  tz.Location? _sourceZone(Map<String, dynamic> json) {
    final start = json['start'];
    return _zone(
      start is Map<String, dynamic> ? start['timeZone'] as String? : null,
    );
  }

  /// The series as Daily would store it, without any exclusions.
  CalendarEvent _masterOf(
    String id,
    DateTime start,
    DateTime end,
    bool allDay,
    String? rawRule,
  ) => CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: end,
    allDay: allDay,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    recurrence: CalendarImportService.recurrenceFromRrule(rawRule),
    createdAt: start,
    updatedAt: start,
  );

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
        : _googleInstant(parsed, raw, value['timeZone'] as String?);
  }

  /// A parsed `dateTime` as a local instant. An offsetless one is a wall
  /// clock in its `timeZone` (when known), not in the device zone.
  DateTime _googleInstant(DateTime parsed, String raw, String? timeZone) {
    final offsetless =
        !parsed.isUtc && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final location = offsetless ? _zone(timeZone) : null;
    if (location == null) return parsed.toLocal();
    return _toLocal(
      tz.TZDateTime(
        location,
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      ),
    );
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

/// Occurrences removed from a recurring series: exact local starts for timed
/// ones, whole days for date values (all-day events and date-only EXDATEs).
class _Exclusions {
  final instants = <DateTime>{};
  final days = <DateTime>{};

  bool excludes(DateTime start) =>
      instants.contains(start) ||
      days.contains(DateTime(start.year, start.month, start.day));

  /// Daily's repeat rule excludes whole local days; [dayOf] maps a timed
  /// start to the stored series' date when that differs from its local date.
  List<DateTime> ruleDates([DateTime? Function(DateTime)? dayOf]) => {
    ...days,
    for (final start in instants)
      dayOf?.call(start) ?? DateTime(start.year, start.month, start.day),
  }.toList()..sort();
}

/// A recurring series in its source zone's wall clock, which is how Google
/// expands it, next to [device]: the series as Daily stores and expands it in
/// device-local time. The two can differ when daylight saving changes differ.
class _WallAxis {
  _WallAxis._(this.zone, this.device, this.wallMaster);

  static _WallAxis? of(
    tz.Location? zone,
    CalendarEvent device,
    String? rawRule,
  ) {
    if (zone == null ||
        !device.recurrence.isRepeating ||
        device.recurrence.rawRule != null) {
      return null;
    }
    final until = device.recurrence.until;
    // A UTC `UNTIL` is an instant: move it to the same wall clock.
    final utcUntil =
        until != null &&
        (rawRule?.toUpperCase().contains(RegExp(r'UNTIL=\d{8}T\d{6}Z')) ??
            false);
    final start = wallOf(zone, device.startAt);
    // The wall-clock end can fall at or before the start across a daylight
    // saving fall-back, so keep the real length.
    final length = device.endAt.difference(device.startAt);
    return _WallAxis._(
      zone,
      device,
      device.copyWith(
        startAt: start,
        endAt: start.add(length.isNegative ? Duration.zero : length),
        recurrence: utcUntil
            ? device.recurrence.copyWith(until: wallOf(zone, until))
            : device.recurrence,
      ),
    );
  }

  final tz.Location zone;
  final CalendarEvent device;
  final CalendarEvent wallMaster;

  static DateTime wallOf(tz.Location? zone, DateTime instant) {
    if (zone == null) return instant;
    final zoned = tz.TZDateTime.from(instant, zone);
    return DateTime(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
      zoned.second,
    );
  }

  /// The date of the stored series' occurrence that stands for the one Google
  /// has at [instant]: the same position in the series, in device time.
  DateTime? deviceDay(DateTime instant) {
    final wall = wallOf(zone, instant);
    final expander = RecurrenceExpander();
    final index = expander
        .expand(
          wallMaster,
          wallMaster.startAt,
          wall.add(const Duration(minutes: 1)),
        )
        .indexWhere((occurrence) => occurrence.startAt == wall);
    if (index < 0) return null;
    final stored = expander.expand(
      device,
      device.startAt,
      wall.add(const Duration(days: 2)),
    );
    if (index >= stored.length) return null;
    final start = stored[index].startAt;
    return DateTime(start.year, start.month, start.day);
  }
}

class _Rdates {
  const _Rdates({
    this.events = const [],
    this.replacedDays = const {},
    this.replacesMaster = false,
  });

  final List<ExternalCalendarEvent> events;

  /// Days of RRULE occurrences that a PERIOD RDATE replaces.
  final Set<DateTime> replacedDays;
  final bool replacesMaster;
}
