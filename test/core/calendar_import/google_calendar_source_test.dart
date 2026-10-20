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
            'originalStartTime': {'dateTime': '2026-10-12T09:00:00+09:00'},
          },
          {
            'id': 'weekly_20261019T000000Z',
            'status': 'confirmed',
            'recurringEventId': 'weekly',
            'originalStartTime': {'dateTime': '2026-10-19T09:00:00+09:00'},
            'summary': '주간 회의',
            'start': {'dateTime': '2026-10-20T11:00:00+09:00'},
            'end': {'dateTime': '2026-10-20T12:00:00+09:00'},
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
            'start': {'dateTime': '2026-10-05T09:00:00+09:00'},
            'end': {'dateTime': '2026-10-05T10:00:00+09:00'},
            'recurrence': [
              'RRULE:FREQ=WEEKLY;BYDAY=MO',
              'EXDATE;TZID=Asia/Seoul:20261026T090000',
              'RDATE;TZID=Asia/Seoul:20261029T090000',
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
      final local = DateTime.parse(iso).toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    expect(series.excludedDates, [
      day('2026-10-12T09:00:00+09:00'),
      day('2026-10-19T09:00:00+09:00'),
      DateTime(2026, 10, 26),
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
      DateTime.parse('2026-10-05T09:00:00+09:00').toLocal(),
      DateTime.parse('2026-10-20T11:00:00+09:00').toLocal(),
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
