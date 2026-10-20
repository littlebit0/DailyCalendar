import 'dart:convert';

import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/calendar_import_service.dart';
import 'package:daily/core/calendar_import/google_calendar_source.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Google 캘린더 목록과 기본 계정 정보를 읽는다', () async {
    final auth = _FakeAuth();
    final source = GoogleCalendarSource(
      authService: auth,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/calendar/v3/users/me/calendarList');
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'person@example.com',
                'summary': '내 캘린더',
                'primary': true,
                'backgroundColor': '#3367d6',
                'defaultReminders': [
                  {'method': 'popup', 'minutes': 30},
                  {'method': 'email', 'minutes': 60},
                ],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final calendars = await source.listCalendars();

    expect(calendars, hasLength(1));
    expect(calendars.single.id, 'person@example.com');
    expect(calendars.single.accountName, 'person@example.com');
    expect(calendars.single.colorValue, 0xff3367d6);
    expect(calendars.single.defaultReminderMinutes, [30]);
    expect(
      auth.requestedScopes,
      contains(GoogleDriveAuthService.calendarReadonlyScope),
    );
  });

  test('특수 문자가 있는 캘린더 ID와 종일 일정을 안전하게 변환한다', () async {
    final auth = _FakeAuth();
    final source = GoogleCalendarSource(
      authService: auth,
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/calendar/v3/calendars/person@example.com/events',
        );
        expect(request.url.toString(), isNot(contains('%2540')));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'event-1',
                'summary': '휴가',
                'description': '메모',
                'location': '서울',
                'htmlLink': 'https://calendar.google.com/event?eid=1',
                'start': {'date': '2026-07-29'},
                'end': {'date': '2026-07-31'},
                'reminders': {
                  'useDefault': false,
                  'overrides': [
                    {'method': 'popup', 'minutes': 10},
                    {'method': 'email', 'minutes': 120},
                  ],
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    const calendar = ImportableCalendar(
      id: 'person@example.com',
      title: '내 캘린더',
      provider: CalendarImportProvider.google,
    );

    final events = await source.loadEvents(const [calendar]);

    expect(events, hasLength(1));
    expect(events.single.title, '휴가');
    expect(events.single.allDay, isTrue);
    expect(events.single.startAt, DateTime(2026, 7, 29));
    expect(events.single.endAt, DateTime(2026, 7, 31));
    expect(events.single.memo, '메모');
    expect(events.single.location, '서울');
    expect(events.single.reminderMinutesBeforeList, [10]);
  });

  test('취소·이동 회차와 EXDATE·RDATE를 반복 원본에 반영한다 (#101)', () async {
    // The exceptions come on the first page, their series on the second.
    final pages = [
      {
        'nextPageToken': 'page-2',
        'items': [
          {
            'id': 'weekly_20261012T000000Z',
            'status': 'cancelled',
            'recurringEventId': 'weekly',
            'originalStartTime': {'dateTime': '2026-10-12T09:00:00'},
          },
          {
            'id': 'weekly_20261019T000000Z',
            'status': 'confirmed',
            'recurringEventId': 'weekly',
            'originalStartTime': {'dateTime': '2026-10-19T09:00:00'},
            'summary': '주간 회의',
            'start': {'dateTime': '2026-10-20T11:00:00'},
            'end': {'dateTime': '2026-10-20T12:00:00'},
          },
          {'id': 'deleted-single', 'status': 'cancelled'},
        ],
      },
      {
        'items': [
          {
            'id': 'weekly',
            'status': 'confirmed',
            'summary': '주간 회의',
            'start': {'dateTime': '2026-10-05T09:00:00'},
            'end': {'dateTime': '2026-10-05T10:00:00'},
            'recurrence': [
              'RRULE:FREQ=WEEKLY;BYDAY=MO',
              'EXDATE:20261026T090000',
              'RDATE:20261029T090000',
            ],
          },
        ],
      },
    ];
    final source = GoogleCalendarSource(
      authService: _FakeAuth(),
      httpClient: MockClient((request) async {
        final page = request.url.queryParameters['pageToken'] == 'page-2'
            ? pages[1]
            : pages[0];
        return http.Response(
          jsonEncode(page),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    const calendar = ImportableCalendar(
      id: 'person@example.com',
      title: '내 캘린더',
      provider: CalendarImportProvider.google,
    );

    final events = await source.loadEvents(const [calendar]);

    expect(events.map((event) => event.sourceId), [
      'weekly_20261019T000000Z',
      'weekly',
      'weekly#rdate#20261029T090000',
    ]);
    final series = events.firstWhere((event) => event.sourceId == 'weekly');
    DateTime day(String iso) {
      final date = DateTime.parse(iso);
      return DateTime(date.year, date.month, date.day);
    }

    expect(series.excludedDates, [
      day('2026-10-12T09:00:00'),
      day('2026-10-19T09:00:00'),
      day('2026-10-26T09:00:00'),
    ]);

    // Normalize as the import does and list the occurrences in October.
    final stored = [
      for (final event in events)
        CalendarEvent(
          id: CalendarImportService.externalEventId(event),
          title: event.title,
          startAt: event.startAt,
          endAt: event.endAt,
          allDay: event.allDay,
          category: EventCategory.basic,
          colorValue: EventCategory.basic.colorValue,
          recurrence: CalendarImportService.recurrenceFromRrule(
            event.recurrenceRule,
          ).copyWith(excludedDates: event.excludedDates),
          createdAt: DateTime(2026, 10),
          updatedAt: DateTime(2026, 10),
        ),
    ];
    final expander = RecurrenceExpander();
    final starts = [
      for (final event in stored)
        for (final occurrence in expander.expand(
          event,
          DateTime(2026, 10),
          DateTime(2026, 11),
        ))
          occurrence.startAt,
    ]..sort();
    expect(starts, [
      DateTime(2026, 10, 5, 9),
      DateTime(2026, 10, 20, 11),
      DateTime(2026, 10, 29, 9),
    ]);
  });

  test('RDATE는 EXDATE·RRULE 회차와 겹치면 빼고 PERIOD와 RRULE 없는 반복도 읽는다', () async {
    final items = [
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {'dateTime': '2026-10-05T09:00:00'},
        'end': {'dateTime': '2026-10-05T10:00:00'},
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          'EXDATE:20261030T090000',
          // Already a Monday occurrence, excluded, duplicated, then new.
          'RDATE:20261012T090000,20261030T090000,20261029T090000',
          'RDATE:20261029T090000',
          'RDATE;VALUE=PERIOD:20261031T090000/20261031T113000,'
              '20261101T090000/PT2H',
        ],
      },
      {
        'id': 'rdate-only',
        'summary': '보강',
        'start': {'dateTime': '2026-11-02T14:00:00'},
        'end': {'dateTime': '2026-11-02T15:00:00'},
        'recurrence': ['RDATE:20261109T140000'],
      },
      {
        'id': 'trip',
        'summary': '여행',
        'start': {'date': '2026-11-06'},
        'end': {'date': '2026-11-08'},
        'recurrence': ['RRULE:FREQ=YEARLY', 'RDATE;VALUE=DATE:20261120'],
      },
    ];
    final source = GoogleCalendarSource(
      authService: _FakeAuth(),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'items': items}),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    const calendar = ImportableCalendar(
      id: 'person@example.com',
      title: '내 캘린더',
      provider: CalendarImportProvider.google,
    );

    final events = await source.loadEvents(const [calendar]);
    final extras = {
      for (final event in events)
        if (event.sourceId.contains('#rdate#'))
          event.sourceId: (event.startAt, event.endAt),
    };

    expect(extras, {
      'weekly#rdate#20261029T090000': (
        DateTime(2026, 10, 29, 9),
        DateTime(2026, 10, 29, 10),
      ),
      'weekly#rdate#20261031T090000/20261031T113000': (
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 10, 31, 11, 30),
      ),
      'weekly#rdate#20261101T090000/PT2H': (
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 11, 1, 11),
      ),
      'rdate-only#rdate#20261109T140000': (
        DateTime(2026, 11, 9, 14),
        DateTime(2026, 11, 9, 15),
      ),
      // Two calendar days, whatever the elapsed hours of the master span.
      'trip#rdate#20261120': (DateTime(2026, 11, 20), DateTime(2026, 11, 22)),
    });
  });
  test('시각이 있는 EXDATE는 정확한 시작 시각으로 RDATE와 비교한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {'dateTime': '2026-10-05T09:00:00'},
        'end': {'dateTime': '2026-10-05T10:00:00'},
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          'EXDATE:20261026T090000',
          'RDATE:20261026T150000,20261026T090000',
        ],
      },
    ]);
    expect(
      events.where((e) => e.sourceId.contains('#rdate#')).map((e) => e.startAt),
      [DateTime(2026, 10, 26, 15)],
    );
  });

  test('RDATE·EXDATE의 TZID를 기기 시간대가 아니라 지정한 시간대로 해석한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {'dateTime': '2026-10-05T13:00:00Z'},
        'end': {'dateTime': '2026-10-05T14:00:00Z'},
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          'EXDATE;TZID=America/New_York:20261026T090000',
          'RDATE;TZID=America/New_York:20261029T090000',
        ],
      },
    ]);
    final series = events.firstWhere((e) => e.sourceId == 'weekly');
    final excluded = DateTime.utc(2026, 10, 26, 13).toLocal();
    expect(series.excludedDates, [
      DateTime(excluded.year, excluded.month, excluded.day),
    ]);
    final rdate = events.firstWhere((e) => e.sourceId.contains('#rdate#'));
    // New York is on daylight time (UTC-4) on both dates.
    expect(rdate.startAt, DateTime.utc(2026, 10, 29, 13).toLocal());
  });

  test('EXDATE가 DTSTART와 같은 반복 없는 원본은 가져오지 않는다', () async {
    final events = await _load([
      {
        'id': 'rdate-only',
        'summary': '보강',
        'start': {'dateTime': '2026-11-02T14:00:00'},
        'end': {'dateTime': '2026-11-02T15:00:00'},
        'recurrence': ['EXDATE:20261102T140000', 'RDATE:20261109T140000'],
      },
    ]);
    expect(events.map((e) => e.sourceId), ['rdate-only#rdate#20261109T140000']);
  });

  test('PERIOD의 일·주 기간은 달력 일수로, 시간 부분은 정확한 길이로 더한다', () async {
    final events = await _load([
      {
        'id': 'multi',
        'summary': '행사',
        'start': {'dateTime': '2026-10-05T09:00:00'},
        'end': {'dateTime': '2026-10-05T10:00:00'},
        'recurrence': [
          'RDATE;VALUE=PERIOD:20261101T090000/P1DT2H,20261108T090000/P1W',
        ],
      },
    ]);
    final ends = {for (final e in events) e.sourceId: e.endAt};
    expect(
      ends['multi#rdate#20261101T090000/P1DT2H'],
      DateTime(2026, 11, 2, 11),
    );
    expect(ends['multi#rdate#20261108T090000/P1W'], DateTime(2026, 11, 15, 9));
  });

  test('같은 시작의 PERIOD RDATE는 만들어진 회차를 PERIOD 길이로 대체한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {'dateTime': '2026-10-05T09:00:00'},
        'end': {'dateTime': '2026-10-05T10:00:00'},
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          'RDATE;VALUE=PERIOD:20261012T090000/20261012T113000,'
              '20261005T090000/PT3H',
        ],
      },
    ]);
    final series = events.firstWhere((e) => e.sourceId == 'weekly');
    expect(series.excludedDates, [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 12),
    ]);
    final extras = {
      for (final e in events)
        if (e.sourceId.contains('#rdate#')) e.startAt: e.endAt,
    };
    expect(extras, {
      DateTime(2026, 10, 12, 9): DateTime(2026, 10, 12, 11, 30),
      DateTime(2026, 10, 5, 9): DateTime(2026, 10, 5, 12),
    });
  });

  test('TZID가 다른 같은 벽시계 RDATE는 서로 다른 ID로 남는다', () async {
    final events = await _load([
      {
        'id': 'multi-zone',
        'summary': '회의',
        'start': {'dateTime': '2026-10-05T09:00:00'},
        'end': {'dateTime': '2026-10-05T10:00:00'},
        'recurrence': [
          'RDATE;TZID=America/New_York:20261029T090000',
          'RDATE;TZID=America/Chicago:20261029T090000',
        ],
      },
    ]);
    final ids = events
        .where((e) => e.sourceId.contains('#rdate#'))
        .map((e) => e.sourceId)
        .toSet();
    expect(ids, hasLength(2));
  });

  test('PERIOD 일수는 선언한 TZID의 달력으로, 예외의 timeZone은 그 시간대로 읽는다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {'dateTime': '2026-10-05T13:00:00Z'},
        'end': {'dateTime': '2026-10-05T14:00:00Z'},
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          // New York falls back on 2026-11-01: one nominal day is 25 hours.
          'RDATE;TZID=America/New_York;VALUE=PERIOD:20261031T090000/P1D',
        ],
      },
      {
        'id': 'weekly_20261012',
        'status': 'cancelled',
        'recurringEventId': 'weekly',
        // 09:00 in New York is 13:00Z, whatever the device zone.
        'originalStartTime': {
          'dateTime': '2026-10-12T09:00:00',
          'timeZone': 'America/New_York',
        },
      },
    ]);
    final rdate = events.firstWhere((e) => e.sourceId.contains('#rdate#'));
    expect(rdate.startAt, DateTime.utc(2026, 10, 31, 13).toLocal());
    expect(rdate.endAt, DateTime.utc(2026, 11, 1, 14).toLocal());
    final excluded = DateTime.utc(2026, 10, 12, 13).toLocal();
    expect(events.firstWhere((e) => e.sourceId == 'weekly').excludedDates, [
      DateTime(excluded.year, excluded.month, excluded.day),
    ]);
  });

  test('UTC PERIOD 일수는 UTC 달력으로 더한다', () async {
    final events = await _load([
      {
        'id': 'utc',
        'summary': '행사',
        'start': {'dateTime': '2026-10-05T13:00:00Z'},
        'end': {'dateTime': '2026-10-05T14:00:00Z'},
        'recurrence': ['RDATE;VALUE=PERIOD:20261031T130000Z/P1D'],
      },
    ]);
    final rdate = events.firstWhere((e) => e.sourceId.contains('#rdate#'));
    expect(rdate.startAt, DateTime.utc(2026, 10, 31, 13).toLocal());
    // New York falls back on 2026-11-01, but the day is added in UTC.
    expect(rdate.endAt, DateTime.utc(2026, 11, 1, 13).toLocal());
  });

  test('RDATE 중복은 시리즈의 start.timeZone 벽시계로 판단한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {
          'dateTime': '2026-10-05T09:00:00-04:00',
          'timeZone': 'America/New_York',
        },
        'end': {
          'dateTime': '2026-10-05T10:00:00-04:00',
          'timeZone': 'America/New_York',
        },
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          // 09:00 New York on the Monday after the fall-back: already in the series.
          'RDATE;TZID=America/New_York:20261102T090000',
        ],
      },
    ]);
    expect(events.where((e) => e.sourceId.contains('#rdate#')), isEmpty);
  });

  test('오프셋 없는 start.dateTime은 start.timeZone으로 읽어 RDATE 중복을 판단한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {
          'dateTime': '2026-10-05T09:00:00',
          'timeZone': 'America/New_York',
        },
        'end': {
          'dateTime': '2026-10-05T10:00:00',
          'timeZone': 'America/New_York',
        },
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=MO',
          'RDATE;TZID=America/New_York:20261012T090000',
        ],
      },
    ]);
    final series = events.firstWhere((e) => e.sourceId == 'weekly');
    expect(series.startAt, DateTime.utc(2026, 10, 5, 13).toLocal());
    expect(events.where((e) => e.sourceId.contains('#rdate#')), isEmpty);
  });

  test('UTC UNTIL은 시리즈 시간대 벽시계로 옮겨 마지막 회차의 RDATE 중복을 거른다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {
          'dateTime': '2026-10-05T00:30:00+09:00',
          'timeZone': 'Asia/Tokyo',
        },
        'end': {
          'dateTime': '2026-10-05T01:30:00+09:00',
          'timeZone': 'Asia/Tokyo',
        },
        'recurrence': [
          // 2026-10-26 00:30 Tokyo is the last occurrence (UNTIL is 15:30Z the day before).
          'RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20261025T153000Z',
          'RDATE;TZID=Asia/Tokyo:20261026T003000',
        ],
      },
    ]);
    expect(events.where((e) => e.sourceId.contains('#rdate#')), isEmpty);
  });

  test('취소된 회차의 제외 날짜는 기기에 저장된 시리즈의 같은 순서 회차 날짜에 맞춘다', () async {
    // New York falls back on 2026-11-01. The device keeps the wall clock of
    // its own zone, so the cancelled 3rd occurrence (2026-11-08 15:30 New York)
    // is the stored series' 3rd occurrence, whatever date its instant has.
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {
          'dateTime': '2026-10-25T15:30:00-04:00',
          'timeZone': 'America/New_York',
        },
        'end': {
          'dateTime': '2026-10-25T16:30:00-04:00',
          'timeZone': 'America/New_York',
        },
        'recurrence': ['RRULE:FREQ=WEEKLY'],
      },
      {
        'id': 'weekly_20261108',
        'status': 'cancelled',
        'recurringEventId': 'weekly',
        'originalStartTime': {
          'dateTime': '2026-11-08T15:30:00-05:00',
          'timeZone': 'America/New_York',
        },
      },
    ]);
    final series = events.firstWhere((e) => e.sourceId == 'weekly');
    final start = series.startAt;
    expect(series.excludedDates, [
      DateTime(start.year, start.month, start.day + 14),
    ]);
  });

  test('DST 종료 구간을 가로지르는 일정도 RDATE 중복 판단에서 길이가 유지된다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '심야 회의',
        'start': {
          'dateTime': '2026-11-01T01:30:00-04:00',
          'timeZone': 'America/New_York',
        },
        'end': {
          'dateTime': '2026-11-01T01:30:00-05:00',
          'timeZone': 'America/New_York',
        },
        'recurrence': [
          'RRULE:FREQ=WEEKLY;BYDAY=SU',
          'RDATE;TZID=America/New_York:20261108T013000',
        ],
      },
    ]);
    expect(events.where((e) => e.sourceId.contains('#rdate#')), isEmpty);
  });

  test('PERIOD RDATE가 대체하는 회차도 기기에 저장된 시리즈의 같은 순서 날짜에서 제외한다', () async {
    final events = await _load([
      {
        'id': 'weekly',
        'summary': '주간 회의',
        'start': {
          'dateTime': '2026-10-25T15:30:00-04:00',
          'timeZone': 'America/New_York',
        },
        'end': {
          'dateTime': '2026-10-25T16:30:00-04:00',
          'timeZone': 'America/New_York',
        },
        'recurrence': [
          'RRULE:FREQ=WEEKLY',
          // The 3rd occurrence (after the fall-back), made 2 hours long.
          'RDATE;TZID=America/New_York;VALUE=PERIOD:20261108T153000/PT2H',
        ],
      },
    ]);
    final series = events.firstWhere((e) => e.sourceId == 'weekly');
    final start = series.startAt;
    expect(series.excludedDates, [
      DateTime(start.year, start.month, start.day + 14),
    ]);
    final rdate = events.firstWhere((e) => e.sourceId.contains('#rdate#'));
    expect(rdate.endAt.difference(rdate.startAt), const Duration(hours: 2));
  });
}

Future<List<ExternalCalendarEvent>> _load(List<Map<String, Object?>> items) {
  const calendar = ImportableCalendar(
    id: 'person@example.com',
    title: '내 캘린더',
    provider: CalendarImportProvider.google,
  );
  return GoogleCalendarSource(
    authService: _FakeAuth(),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode({'items': items}),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  ).loadEvents(const [calendar]);
}

class _FakeAuth extends GoogleDriveAuthService {
  _FakeAuth() : super(useDesktopOAuth: false);

  List<String> requestedScopes = const [];

  @override
  GoogleDriveAccount? get currentAccount =>
      const GoogleDriveAccount(email: 'person@example.com');

  @override
  Future<Map<String, String>?> authorizationHeadersForScopes(
    Iterable<String> requestedScopes, {
    bool promptIfNecessary = false,
  }) async {
    this.requestedScopes = requestedScopes.toList(growable: false);
    return const {'Authorization': 'Bearer test-token'};
  }
}
