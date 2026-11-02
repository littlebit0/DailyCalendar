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
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
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
