import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/calendar_import_service.dart';
import 'package:daily/core/calendar_import/google_calendar_source.dart';
import 'package:daily/core/calendar_import/native_calendar_source.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/data/recurrence_expander.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarImportService.externalEventId', () {
    ExternalCalendarEvent event({
      String sourceId = 'event-1',
      String calendarId = 'calendar-1',
      CalendarImportProvider provider = CalendarImportProvider.google,
    }) {
      return ExternalCalendarEvent(
        sourceId: sourceId,
        calendarId: calendarId,
        provider: provider,
        title: '일정',
        startAt: DateTime(2026, 7, 29, 9),
        endAt: DateTime(2026, 7, 29, 10),
        allDay: false,
      );
    }

    test('같은 외부 일정은 항상 같은 Daily ID를 만든다', () {
      expect(
        CalendarImportService.externalEventId(event()),
        CalendarImportService.externalEventId(event()),
      );
    });

    test('공급자, 캘린더 또는 원본 ID가 다르면 Daily ID도 다르다', () {
      final base = CalendarImportService.externalEventId(event());
      expect(
        CalendarImportService.externalEventId(
          event(provider: CalendarImportProvider.apple),
        ),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(calendarId: 'other')),
        isNot(base),
      );
      expect(
        CalendarImportService.externalEventId(event(sourceId: 'other')),
        isNot(base),
      );
    });
  });

  test('가져온 캘린더 분류 ID는 공급자와 원본 캘린더별로 안정적이다', () {
    const apple = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.apple,
      colorValue: 0xff123456,
    );
    const google = ImportableCalendar(
      id: 'calendar-1',
      title: '회사',
      provider: CalendarImportProvider.google,
      colorValue: 0xff123456,
    );

    expect(
      CalendarImportService.importedCategoryId(apple),
      CalendarImportService.importedCategoryId(apple),
    );
    expect(
      CalendarImportService.importedCategoryId(apple),
      isNot(CalendarImportService.importedCategoryId(google)),
    );
  });

  group('CalendarImportService.recurrenceFromRrule', () {
    test('빈 값은 반복 없음으로 변환한다', () {
      expect(
        CalendarImportService.recurrenceFromRrule(null).frequency,
        RecurrenceFrequency.none,
      );
    });

    test('주간 반복의 간격과 횟수를 보존한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'RRULE:FREQ=WEEKLY;INTERVAL=2;COUNT=8',
      );
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.count, 8);
    });

    test('요일·서수 요일·월 내 날짜 조건을 보존한다', () {
      var rule = CalendarImportService.recurrenceFromRrule(
        'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4',
      );
      expect(rule.byDay, ['MO', 'WE']);
      expect(rule.count, 4);
      rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=MONTHLY;BYDAY=2TU;COUNT=3',
      );
      expect(rule.byDay, ['2TU']);
      rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
      );
      expect(rule.bySetPos, [-1]);
      rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=MONTHLY;BYMONTHDAY=15,-1',
      );
      expect(rule.byMonthDay, [15, -1]);
      rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=YEARLY;BYMONTH=11;BYDAY=4TH',
      );
      expect(rule.byMonth, [11]);
      expect(rule.byDay, ['4TH']);
      expect(rule.rawRule, isNull);
    });

    test('표현할 수 없는 조건은 단순 반복으로 바꾸지 않고 원문을 보존한다', () {
      for (final text in [
        'FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO',
        'FREQ=HOURLY;INTERVAL=2',
        'FREQ=WEEKLY;BYDAY=2MO',
        'FREQ=MONTHLY;BYSETPOS=1',
        'FREQ=YEARLY;BYDAY=1MO',
        'FREQ=WEEKLY;INTERVAL=2;WKST=SU;BYDAY=MO',
        'FREQ=DAILY;BYHOUR=9',
      ]) {
        final rule = CalendarImportService.recurrenceFromRrule(text);
        expect(rule.frequency, RecurrenceFrequency.none, reason: text);
        expect(rule.rawRule, text, reason: text);
      }
    });

    test('주 시작(WKST)이 시작일 요일과 같으면 격주 규칙을 지원한다 (#802)', () {
      const text = 'FREQ=WEEKLY;INTERVAL=2;WKST=SU;BYDAY=SU,WE';
      final sunday = DateTime(2026, 1, 4, 9);
      var rule = CalendarImportService.recurrenceFromRrule(
        text,
        startAt: sunday,
      );
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.byDay, ['SU', 'WE']);
      expect(rule.rawRule, isNull);
      rule = CalendarImportService.recurrenceFromRrule(
        text,
        startAt: DateTime(2026, 1, 7, 9),
      );
      expect(rule.frequency, RecurrenceFrequency.none);
      expect(rule.rawRule, text);
      rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=TH,MO',
        startAt: DateTime(2026, 1, 8, 9),
      );
      expect(rule.byDay, ['TH', 'MO']);
      expect(rule.rawRule, isNull);
    });

    test('격주 규칙은 주 시작(WKST, 기본 월요일)을 저장해 같은 주로 확장한다 (#843)', () {
      final thursday = DateTime(2026, 1, 8, 9);
      List<String> dates(RecurrenceRule rule) => [
        for (final occurrence in RecurrenceExpander().expand(
          CalendarEvent(
            id: 'imported',
            title: '격주',
            startAt: thursday,
            endAt: thursday.add(const Duration(hours: 1)),
            allDay: false,
            category: EventCategory.basic,
            colorValue: EventCategory.basic.colorValue,
            recurrence: rule,
            createdAt: thursday,
            updatedAt: thursday,
          ),
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 6),
        ))
          occurrence.startAt.toIso8601String().substring(0, 10),
      ];

      final imported = CalendarImportService.recurrenceFromRrule(
        'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH',
        startAt: thursday,
      );
      expect(imported.weekStart, DateTime.monday);
      expect(dates(imported), [
        '2026-01-08',
        '2026-01-19',
        '2026-01-22',
        '2026-02-02',
        '2026-02-05',
      ]);

      final explicit = CalendarImportService.recurrenceFromRrule(
        'FREQ=WEEKLY;INTERVAL=2;WKST=TH;BYDAY=MO,TH',
        startAt: thursday,
      );
      expect(explicit.weekStart, DateTime.thursday);

      // 앱에서 만든 격주 규칙은 시작 요일을 주 시작으로 본다.
      const inApp = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        byDay: ['MO', 'TH'],
      );
      expect(dates(explicit), dates(inApp));
      expect(dates(inApp), [
        '2026-01-08',
        '2026-01-12',
        '2026-01-22',
        '2026-01-26',
        '2026-02-05',
      ]);

      // 매주 규칙은 주 시작과 무관하므로 저장하지 않는다.
      final weekly = CalendarImportService.recurrenceFromRrule(
        'FREQ=WEEKLY;BYDAY=MO,TH',
        startAt: thursday,
      );
      expect(weekly.weekStart, isNull);
      expect(dates(weekly).take(3), ['2026-01-08', '2026-01-12', '2026-01-15']);
    });

    test('UTC 종료 시각을 로컬 DateTime으로 변환한다', () {
      final rule = CalendarImportService.recurrenceFromRrule(
        'FREQ=DAILY;UNTIL=20260731T000000Z',
      );
      expect(rule.frequency, RecurrenceFrequency.daily);
      expect(rule.until, DateTime.utc(2026, 7, 31).toLocal());
    });
  });

  test(
    'imported category save preserves a concurrent unrelated setting change',
    () async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = _ConcurrentImportSettingsRepository(
        preferences: preferences,
      )..injectThemeChangeBeforeNextSave();
      final eventRepository = _UnusedEventRepository();
      final service = CalendarImportService(
        nativeSource: _EmptyNativeCalendarSource(),
        googleSource: GoogleCalendarSource(
          authService: GoogleDriveAuthService(useDesktopOAuth: false),
        ),
        eventRepository: eventRepository,
        eventCommandService: EventCommandService(
          repository: eventRepository,
          settingsRepository: settingsRepository,
          notificationService: _UnusedNotificationService(),
          syncService: _UnusedSyncService(),
        ),
        settingsRepository: settingsRepository,
      );
      const calendar = ImportableCalendar(
        id: 'work-calendar',
        title: 'Work',
        provider: CalendarImportProvider.samsung,
        colorValue: 0xff123456,
      );

      final result = await service.importCalendars(const [calendar]);

      expect(result.imported, 0);
      expect(result.failed, 0);
      expect(settingsRepository.capturedChangedFrom, isNotNull);
      expect(settingsRepository.load().themeMode, AppThemeMode.dark);
      expect(
        settingsRepository.load().categories.any(
          (category) =>
              category.id == CalendarImportService.importedCategoryId(calendar),
        ),
        isTrue,
      );
    },
  );

  test('업데이트가 필요해지면 불러온 일정을 저장하지 않고 가져오기를 취소한다', () async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    // Touching this repository throws: nothing may be looked up or written.
    final eventRepository = _UnusedEventRepository();
    var blocked = false;
    final service = CalendarImportService(
      nativeSource: _OneEventNativeCalendarSource(() => blocked = true),
      googleSource: GoogleCalendarSource(
        authService: GoogleDriveAuthService(useDesktopOAuth: false),
      ),
      eventRepository: eventRepository,
      eventCommandService: EventCommandService(
        repository: eventRepository,
        settingsRepository: settingsRepository,
        notificationService: _UnusedNotificationService(),
        syncService: _UnusedSyncService(),
      ),
      settingsRepository: settingsRepository,
      blocked: () => blocked,
    );
    const calendar = ImportableCalendar(
      id: 'work-calendar',
      title: 'Work',
      provider: CalendarImportProvider.samsung,
      colorValue: 0xff123456,
    );

    await expectLater(
      service.importCalendars(const [calendar]),
      throwsA(isA<CalendarImportCancelled>()),
    );
  });

  test('삭제한 외부 일정은 삭제 기록 정리 전후 모두 다시 가져오지 않는다 (#841)', () async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final preferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(preferences: preferences);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final eventRepository = DriftEventRepository(database);
    final commands = EventCommandService(
      repository: eventRepository,
      settingsRepository: settingsRepository,
      notificationService: _SilentNotificationService(),
      syncService: _SilentSyncService(),
    );
    final source = _ListNativeCalendarSource([_pastEvent('one')]);
    final service = CalendarImportService(
      nativeSource: source,
      googleSource: GoogleCalendarSource(
        authService: GoogleDriveAuthService(useDesktopOAuth: false),
      ),
      eventRepository: eventRepository,
      eventCommandService: commands,
      settingsRepository: settingsRepository,
    );
    const calendar = ImportableCalendar(
      id: 'work-calendar',
      title: 'Work',
      provider: CalendarImportProvider.samsung,
      colorValue: 0xff123456,
    );

    final first = await service.importCalendars(const [calendar]);
    expect((first.imported, first.skipped, first.failed), (1, 0, 0));
    final id = (await eventRepository.allEventsForSync()).single.id;

    // 기존 일정 건너뛰기는 그대로다.
    final again = await service.importCalendars(const [calendar]);
    expect((again.imported, again.skipped, again.failed), (0, 1, 0));

    await commands.delete(id);
    final softDeleted = await service.importCalendars(const [calendar]);
    expect(
      (softDeleted.imported, softDeleted.skipped, softDeleted.failed),
      (0, 1, 0),
    );

    await eventRepository.compactDeletedEvents(DateTime(2026, 11, 17));
    expect(await eventRepository.findById(id), isNull);
    // 처음 보는 일정은 삭제 기록이 있는 일정과 함께 와도 저장된다.
    source.events.add(_pastEvent('two'));
    final compacted = await service.importCalendars(const [calendar]);
    expect(
      (compacted.imported, compacted.skipped, compacted.failed),
      (1, 1, 0),
    );
    expect(await eventRepository.findById(id), isNull);
    expect((await eventRepository.allEventsForSync()).single.id, isNot(id));
  });
  group('Google 종일 일정 알림 기준 변환 (#863)', () {
    // Google이 정한 알림 시각: 시작일 00:00에서 분을 뺀 시각.
    DateTime googleAt(DateTime day, int minutes) => DateTime(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(minutes: minutes));
    // Daily가 예약하는 시각: 종일 알림 시각에서 저장된 분을 뺀 시각.
    DateTime dailyAt(DateTime day, int minutes, int hour, int minute) =>
        DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        ).subtract(Duration(minutes: minutes));

    test('하루 전 오전 9시(900분)는 종일 알림 09:00 기준 1440분으로 바꾼다', () {
      expect(
        CalendarImportService.googleAllDayReminderMinutes(
          const [900],
          hour: 9,
          minute: 0,
        ),
        [1440],
      );
    });

    test('당일 00:00(0분)은 종일 알림 시각만큼의 분으로 바꾼다', () {
      // 문서상 분은 0~40320이라 00:00 이후인 "당일 오전 9시"는 표현되지 않는다.
      expect(
        CalendarImportService.googleAllDayReminderMinutes(
          const [0],
          hour: 9,
          minute: 0,
        ),
        [540],
      );
    });

    test('종일 알림 시각이 0시가 아니고 분이 있어도 같은 시각에 울린다', () {
      for (final day in [
        DateTime(2026, 11, 20),
        // America/New_York DST 시작·종료 다음 날.
        DateTime(2026, 3, 9),
        DateTime(2026, 11, 2),
      ]) {
        for (final (hour, minute) in [(9, 0), (7, 30), (0, 0), (23, 45)]) {
          for (final google in [0, 900, 1440, 40320]) {
            final stored = CalendarImportService.googleAllDayReminderMinutes(
              [google],
              hour: hour,
              minute: minute,
            ).single;
            expect(
              dailyAt(day, stored, hour, minute),
              googleAt(day, google),
              reason: '$day $hour:$minute $google',
            );
          }
        }
      }
    });

    test('가져오기는 Google 종일 일정만 바꾸고 시간 지정 일정과 기기 캘린더는 그대로 둔다', () async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': true,
        'allDayReminderHour': 7,
        'allDayReminderMinute': 30,
      });
      final preferences = await SharedPreferences.getInstance();
      final settingsRepository = SettingsRepository(preferences: preferences);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final eventRepository = DriftEventRepository(database);
      ExternalCalendarEvent event(
        String id,
        CalendarImportProvider provider, {
        required bool allDay,
      }) => ExternalCalendarEvent(
        sourceId: id,
        calendarId: 'work-calendar',
        provider: provider,
        title: id,
        startAt: allDay ? DateTime(2020, 11, 20) : DateTime(2020, 11, 20, 14),
        endAt: allDay ? DateTime(2020, 11, 21) : DateTime(2020, 11, 20, 15),
        allDay: allDay,
        reminderMinutesBeforeList: const [0, 900],
      );
      final googleAllDay = event(
        'google-all-day',
        CalendarImportProvider.google,
        allDay: true,
      );
      final googleTimed = event(
        'google-timed',
        CalendarImportProvider.google,
        allDay: false,
      );
      final nativeAllDay = event(
        'native-all-day',
        CalendarImportProvider.samsung,
        allDay: true,
      );
      final service = CalendarImportService(
        nativeSource: _ListNativeCalendarSource([nativeAllDay]),
        googleSource: _ListGoogleCalendarSource([googleAllDay, googleTimed]),
        eventRepository: eventRepository,
        eventCommandService: EventCommandService(
          repository: eventRepository,
          settingsRepository: settingsRepository,
          notificationService: _SilentNotificationService(),
          syncService: _SilentSyncService(),
        ),
        settingsRepository: settingsRepository,
      );

      final result = await service.importCalendars(const [
        ImportableCalendar(
          id: 'work-calendar',
          title: 'Work',
          provider: CalendarImportProvider.google,
        ),
        ImportableCalendar(
          id: 'work-calendar',
          title: 'Work',
          provider: CalendarImportProvider.samsung,
        ),
      ]);

      expect((result.imported, result.failed), (3, 0));
      Future<List<int>> stored(ExternalCalendarEvent external) async =>
          (await eventRepository.findById(
            CalendarImportService.externalEventId(external),
          ))!.reminderMinutesBeforeList;
      expect(await stored(googleAllDay), [450, 1350]);
      expect(await stored(googleTimed), [0, 900]);
      expect(await stored(nativeAllDay), [0, 900]);
    });
  });
}

ExternalCalendarEvent _pastEvent(String sourceId) => ExternalCalendarEvent(
  sourceId: sourceId,
  calendarId: 'work-calendar',
  provider: CalendarImportProvider.samsung,
  title: '회의',
  startAt: DateTime(2020, 11, 2, 9),
  endAt: DateTime(2020, 11, 2, 10),
  allDay: false,
);

class _ListNativeCalendarSource extends NativeCalendarSource {
  _ListNativeCalendarSource(this.events);
  final List<ExternalCalendarEvent> events;
  @override
  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async => List.of(events);
}

class _ListGoogleCalendarSource extends GoogleCalendarSource {
  _ListGoogleCalendarSource(this.events)
    : super(authService: GoogleDriveAuthService(useDesktopOAuth: false));
  final List<ExternalCalendarEvent> events;
  @override
  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async => List.of(events);
}

class _SilentNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _SilentSyncService implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _OneEventNativeCalendarSource extends NativeCalendarSource {
  _OneEventNativeCalendarSource(this.onLoad);
  final void Function() onLoad;
  @override
  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async {
    onLoad();
    return [
      ExternalCalendarEvent(
        sourceId: 'one',
        calendarId: 'work-calendar',
        provider: CalendarImportProvider.samsung,
        title: '회의',
        startAt: DateTime(2026, 11, 2, 9),
        endAt: DateTime(2026, 11, 2, 10),
        allDay: false,
      ),
    ];
  }
}

class _EmptyNativeCalendarSource extends NativeCalendarSource {
  @override
  Future<List<ExternalCalendarEvent>> loadEvents(
    Iterable<ImportableCalendar> calendars,
  ) async => const [];
}

class _ConcurrentImportSettingsRepository extends SettingsRepository {
  _ConcurrentImportSettingsRepository({required super.preferences});

  var _injectThemeChange = false;
  AppSettings? capturedChangedFrom;

  void injectThemeChangeBeforeNextSave() {
    capturedChangedFrom = null;
    _injectThemeChange = true;
  }

  @override
  Future<void> save(
    AppSettings settings, {
    bool markSyncPending = true,
    AppSettings? changedFrom,
  }) async {
    if (_injectThemeChange) {
      _injectThemeChange = false;
      capturedChangedFrom = changedFrom;
      final concurrentBase = load();
      await super.save(
        concurrentBase.copyWith(themeMode: AppThemeMode.dark),
        markSyncPending: false,
        changedFrom: concurrentBase,
      );
    }
    await super.save(
      settings,
      markSyncPending: markSyncPending,
      changedFrom: changedFrom,
    );
  }
}

class _UnusedEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

class _UnusedNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

class _UnusedSyncService implements SyncService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}
