import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/widgets/calendar_widget_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('per-day D-day lists are re-ranked and beyond the first six (#103)', () {
    final now = DateTime(2026, 10, 1, 9);
    // Seven D-days: one that has passed and six later ones. On the first day
    // the past one is among the nearest six; ten days on, it no longer is and
    // the seventh target has taken its place.
    final events = [
      _event(id: 'past', title: 'past', startAt: DateTime(2026, 9, 28, 9))
          .copyWith(showDday: true),
      for (var i = 0; i < 6; i++)
        _event(
          id: 'later-$i',
          title: 'later-$i',
          startAt: DateTime(2026, 10, 3 + i * 3, 9),
        ).copyWith(showDday: true),
    ];
    final snapshot = CalendarWidgetSnapshotBuilder.build(
      now: now,
      settings: AppSettings(language: AppLanguage.korean),
      gridStart: DateTime(2026, 9, 27),
      monthEvents: const [],
      allEvents: events,
    );
    List<String> idsOn(String date) => [
      for (final view in (snapshot['dailyViews'] as List).cast<Map>())
        if (view['date'] == date)
          for (final dday in (view['ddays'] as List).cast<Map>())
            dday['id'] as String,
    ];
    expect(idsOn('2026-10-01'), contains('past'));
    expect(idsOn('2026-10-01'), isNot(contains('later-5')));
    // From Oct 11 the nearest six no longer include the old target.
    expect(idsOn('2026-10-11'), isNot(contains('past')));
    expect(idsOn('2026-10-11'), contains('later-5'));
  });

  test('snapshot carries per-day views and D-day target dates (#103)', () {
    final now = DateTime(2026, 10, 31, 9);
    final gridStart = DateTime(2026, 9, 27);
    final tomorrow = _event(
      id: 'next',
      title: 'Next day',
      startAt: DateTime(2026, 11, 1, 10),
    );
    final dday = _event(
      id: 'dday',
      title: 'Exam',
      startAt: DateTime(2026, 11, 10, 9),
    ).copyWith(showDday: true);
    final snapshot = CalendarWidgetSnapshotBuilder.build(
      now: now,
      settings: AppSettings(language: AppLanguage.korean),
      gridStart: gridStart,
      monthEvents: [tomorrow],
      allEvents: [dday],
    );

    expect(snapshot['snapshotDate'], '2026-10-31');
    final views = (snapshot['dailyViews'] as List).cast<Map>();
    expect(views, hasLength(42));
    expect(views.first['date'], '2026-09-27');
    final today = views.firstWhere((view) => view['date'] == '2026-10-31');
    final next = views.firstWhere((view) => view['date'] == '2026-11-01');
    expect(today['todayEvents'], isEmpty);
    expect((next['todayEvents'] as List).single['eventId'], 'next');
    expect(next['todayTitle'], isNot(today['todayTitle']));
    final ddays = (snapshot['ddays'] as List).cast<Map>();
    expect(ddays.single['daysRemaining'], 10);
    // Each cached day carries its own D-day list, measured from that day.
    final remainingOn = {
      for (final view in views)
        view['date']: (view['ddays'] as List).cast<Map>().single['daysRemaining'],
    };
    expect(remainingOn['2026-10-31'], 10);
    expect(remainingOn['2026-11-01'], 9);
    expect(remainingOn['2026-11-07'], 3);
    expect(snapshot['utcOffsetMinutes'], now.timeZoneOffset.inMinutes);
    expect(snapshot['utcOffsetAtMs'], now.millisecondsSinceEpoch);
  });

  group('repeating D-day (#883)', () {
    Map<dynamic, dynamic> ddayOf(
      CalendarEvent event, {
      DateTime? now,
      String? on,
    }) {
      final snapshot = CalendarWidgetSnapshotBuilder.build(
        now: now ?? DateTime(2026, 11, 15, 9),
        settings: AppSettings(language: AppLanguage.korean),
        gridStart: DateTime(2026, 10, 25),
        monthEvents: const [],
        allEvents: [event.copyWith(showDday: true)],
      );
      if (on == null) return (snapshot['ddays'] as List).cast<Map>().single;
      final view = (snapshot['dailyViews'] as List).cast<Map>().firstWhere(
        (view) => view['date'] == on,
      );
      return (view['ddays'] as List).cast<Map>().single;
    }

    final birthday =
        _event(
          id: 'birthday',
          title: '생일',
          startAt: DateTime(2024, 12, 1),
        ).copyWith(
          endAt: DateTime(2024, 12, 2),
          allDay: true,
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.yearly,
          ),
        );

    test('a yearly event counts down to its next occurrence', () {
      final dday = ddayOf(birthday);
      expect(dday['id'], 'birthday');
      expect(dday['dateLabel'], '2026.12.01');
      expect(dday['daysRemaining'], 16);
    });

    test('each cached day measures from its own next occurrence', () {
      expect(ddayOf(birthday, on: '2026-12-01')['daysRemaining'], 0);
      final after = ddayOf(birthday, on: '2026-12-02');
      expect(after['dateLabel'], '2027.12.01');
      expect(after['daysRemaining'], 364);
    });

    test('a long interval still counts down to its far occurrence', () {
      final dday = ddayOf(
        birthday.copyWith(
          startAt: DateTime(2025, 12, 1),
          endAt: DateTime(2025, 12, 2),
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.yearly,
            interval: 10,
          ),
        ),
      );
      expect(dday['dateLabel'], '2035.12.01');
      expect(dday['daysRemaining'], greaterThan(3000));
    });

    test('an excluded occurrence is skipped', () {
      final dday = ddayOf(
        birthday.copyWith(
          recurrence: birthday.recurrence.copyWith(
            excludedDates: [DateTime(2026, 12, 1)],
          ),
        ),
      );
      expect(dday['dateLabel'], '2027.12.01');
    });

    test('an ended series counts up from its last occurrence', () {
      final dday = ddayOf(
        birthday.copyWith(
          recurrence: birthday.recurrence.copyWith(
            until: DateTime(2025, 12, 31),
          ),
        ),
      );
      expect(dday['dateLabel'], '2025.12.01');
      expect(dday['daysRemaining'], -349);
    });

    test('a non-repeating D-day is unchanged', () {
      final dday = ddayOf(
        birthday.copyWith(recurrence: const RecurrenceRule()),
      );
      expect(dday['dateLabel'], '2024.12.01');
      expect(dday['daysRemaining'], -714);
    });

    test('the nearest six are ranked by the next occurrence', () {
      final snapshot = CalendarWidgetSnapshotBuilder.build(
        now: DateTime(2026, 11, 15, 9),
        settings: AppSettings(language: AppLanguage.korean),
        gridStart: DateTime(2026, 10, 25),
        monthEvents: const [],
        allEvents: [
          for (var index = 0; index < 6; index++)
            _event(
              id: 'later-$index',
              title: 'Later',
              startAt: DateTime(2027, 1, 10 + index),
            ).copyWith(showDday: true),
          birthday.copyWith(showDday: true),
        ],
      );
      expect((snapshot['ddays'] as List).cast<Map>().first['id'], 'birthday');
    });
  });

  test('widget day lists follow each event\'s following-day choice (#791)', () {
    final shift = _event(
      id: 'shift',
      title: '야간 근무',
      startAt: DateTime(2026, 10, 29, 22),
    ).copyWith(endAt: DateTime(2026, 10, 30, 6));
    final party = shift.copyWith(
      id: 'party',
      showOvernightOnFollowingDays: false,
    );
    final snapshot = CalendarWidgetSnapshotBuilder.build(
      now: DateTime(2026, 10, 30, 9),
      settings: AppSettings(language: AppLanguage.korean),
      gridStart: DateTime(2026, 9, 27),
      monthEvents: [shift, party],
      allEvents: const [],
    );
    List<String> monthIdsOn(String date) => [
      for (final day in (snapshot['monthDays'] as List).cast<Map>())
        if (day['date'] == date)
          for (final event in (day['events'] as List).cast<Map>())
            event['eventId'] as String,
    ];
    expect(monthIdsOn('2026-10-29'), unorderedEquals(['shift', 'party']));
    expect(monthIdsOn('2026-10-30'), ['shift']);
    expect(
      (snapshot['todayEvents'] as List).cast<Map>().map((e) => e['eventId']),
      ['shift'],
    );
  });

  test(
    'widget action retains the tapped date and rejects legacy whole-series ambiguity',
    () {
      final source =
          _event(
            id: 'series',
            title: 'repeat',
            startAt: DateTime(2026, 10, 1, 9),
          ).copyWith(
            recurrence: const RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
            ),
          );
      const key = 'series@2026-10-15T09:00:00.000';
      final action = CalendarWidgetTodoAction.fromMap({
        'token': 'old-tap',
        'eventId': 'series',
        'completed': true,
        'occurrenceId': key,
      })!;
      final target = action.targetFor(source)!;
      expect(target.occurrenceId, key);
      expect(target.startAt, DateTime(2026, 10, 15, 9));
      expect(target.endAt, target.startAt.add(source.duration));
      final legacy = CalendarWidgetTodoAction.fromMap({
        'token': 'legacy',
        'eventId': 'series',
        'completed': true,
      })!;
      expect(legacy.targetFor(source), isNull);
      expect(
        legacy.targetFor(source.copyWith(recurrence: const RecurrenceRule())),
        isNotNull,
      );
      expect(
        const CalendarWidgetTodoAction(
          token: 'bad',
          eventId: 'series',
          completed: true,
          occurrenceId: 'other@2026-10-15',
        ).targetFor(source),
        isNull,
      );
    },
  );

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'english'});
  });

  for (final entry in const <TargetPlatform, String>{
    TargetPlatform.iOS: CalendarWidgetChannelContract.appleChannel,
    TargetPlatform.macOS: CalendarWidgetChannelContract.appleChannel,
    TargetPlatform.android: CalendarWidgetChannelContract.androidChannel,
    TargetPlatform.windows: CalendarWidgetChannelContract.windowsChannel,
  }.entries) {
    test('${entry.key.name} sends the common snapshot contract', () async {
      final channel = MethodChannel(entry.value);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final now = DateTime(2026, 8, 26, 9);
      final event = _event(id: 'todo-1', title: 'Ship release', startAt: now);
      final preferences = await SharedPreferences.getInstance();
      final service = CalendarWidgetService(
        eventRepository: _FakeEventRepository([event]),
        settingsRepository: SettingsRepository(preferences: preferences),
        targetPlatform: entry.key,
        channel: channel,
      );
      addTearDown(service.dispose);

      await service.refresh(now: now);

      expect(service.isSupported, isTrue);
      expect(calls, hasLength(1));
      expect(
        calls.single.method,
        CalendarWidgetChannelContract.updateSnapshotMethod,
      );
      final snapshot = Map<Object?, Object?>.from(
        calls.single.arguments as Map,
      );
      expect(snapshot['localeTag'], 'en');
      expect(snapshot['themeMode'], AppThemeMode.system.name);
      expect(snapshot['todayEvents'], hasLength(1));
      expect(snapshot['scheduleEvents'], hasLength(1));
      expect(snapshot['monthDays'], hasLength(42));
      final dates = [
        for (final day in snapshot['monthDays'] as List)
          DateTime.parse((day as Map)['date'] as String),
      ];
      for (var i = 1; i < dates.length; i++) {
        final previous = DateTime.utc(
          dates[i - 1].year,
          dates[i - 1].month,
          dates[i - 1].day,
        );
        final current = DateTime.utc(
          dates[i].year,
          dates[i].month,
          dates[i].day,
        );
        expect(current.difference(previous).inDays, 1, reason: 'cell $i');
      }
    });
  }

  test(
    'school cache grant survives missing fresh auth while retaining explicit visibility',
    () async {
      const channel = MethodChannel(CalendarWidgetChannelContract.appleChannel);
      final snapshots = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            snapshots.add(Map<Object?, Object?>.from(call.arguments as Map));
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final now = DateTime(2026, 9, 26);
      final metadata = LmsEventMetadata(
        schoolId: 'smu',
        ownerId: 'student@example.com',
        lmsUserId: '1',
        courseId: '2',
        courseTitle: '수업',
        activityType: 'assignment',
        activityId: '3',
        sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=3',
        dueAt: now,
      );
      final deadline = _event(
        id: 'lms:due',
        title: '마감',
        startAt: now,
      ).copyWith(endAt: now, allDay: false, lms: metadata);
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'student@example.com'),
      );
      var visible = true;
      DateTime? verified = now.subtract(const Duration(minutes: 1));
      final service = CalendarWidgetService(
        eventRepository: _FakeEventRepository([deadline]),
        settingsRepository: settings,
        targetPlatform: TargetPlatform.macOS,
        channel: channel,
        isEventVisible: (_) => visible,
        lmsVerifiedAt: () => verified,
      );
      addTearDown(service.dispose);
      await service.refresh(now: now);
      expect(snapshots.last['todayEvents'], hasLength(1));
      final grant = snapshots.last['lmsVisibility'] as Map;
      expect(grant['ownerId'], 'student@example.com');
      expect(grant['checkedAt'], verified.millisecondsSinceEpoch);
      expect(grant['eventIds'], ['lms:due']);
      verified = null;
      await service.refresh(now: now);
      expect(snapshots.last['todayEvents'], hasLength(1));
      expect((snapshots.last['lmsVisibility'] as Map)['eventIds'], ['lms:due']);
      expect((snapshots.last['lmsVisibility'] as Map)['checkedAt'], isNull);
      visible = false;
      await service.refresh(now: now);
      expect(snapshots.last['todayEvents'], isEmpty);
      expect((snapshots.last['lmsVisibility'] as Map)['eventIds'], isEmpty);
      visible = true;
      await settings.saveGoogleAccount(
        const GoogleAccount(email: 'other@example.com'),
      );
      await service.refresh(now: now);
      expect((snapshots.last['lmsVisibility'] as Map)['eventIds'], isEmpty);
    },
  );

  test(
    'Windows uses the common pending and acknowledgement action shape',
    () async {
      const channel = MethodChannel(
        CalendarWidgetChannelContract.windowsChannel,
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method ==
                CalendarWidgetChannelContract.pendingTodoActionsMethod) {
              return <Map<String, Object?>>[
                {'token': 'action-1', 'eventId': 'todo-1', 'completed': true},
                {'token': 'invalid'},
              ];
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final preferences = await SharedPreferences.getInstance();
      final service = CalendarWidgetService(
        eventRepository: _FakeEventRepository(const []),
        settingsRepository: SettingsRepository(preferences: preferences),
        targetPlatform: TargetPlatform.windows,
        channel: channel,
      );
      addTearDown(service.dispose);

      final actions = await service.pendingTodoActions();
      await service.acknowledgeTodoActions(
        actions.map((action) => action.token),
      );

      expect(actions, hasLength(1));
      expect(actions.single.eventId, 'todo-1');
      expect(actions.single.completed, isTrue);
      expect(calls.map((call) => call.method), [
        CalendarWidgetChannelContract.pendingTodoActionsMethod,
        CalendarWidgetChannelContract.acknowledgeTodoActionsMethod,
      ]);
      expect(calls.last.arguments, {
        'tokens': ['action-1'],
      });
    },
  );

  test('native Todo callback is platform-neutral', () async {
    const channel = MethodChannel(CalendarWidgetChannelContract.androidChannel);
    final preferences = await SharedPreferences.getInstance();
    final service = CalendarWidgetService(
      eventRepository: _FakeEventRepository(const []),
      settingsRepository: SettingsRepository(preferences: preferences),
      targetPlatform: TargetPlatform.android,
      channel: channel,
    );
    addTearDown(service.dispose);

    final changed = service.todoActionChanges.first;
    await service.handleNativeMethodCall(
      const MethodCall(
        CalendarWidgetChannelContract.todoActionsChangedCallback,
      ),
    );

    await changed;
  });

  test('unsupported platforms do not expose a widget channel', () {
    expect(
      CalendarWidgetChannelContract.channelNameFor(TargetPlatform.linux),
      isNull,
    );
    expect(
      CalendarWidgetChannelContract.channelNameFor(TargetPlatform.fuchsia),
      isNull,
    );
  });
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this.events);

  final List<CalendarEvent> events;

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async {
    return events;
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async {
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CalendarEvent _event({
  required String id,
  required String title,
  required DateTime startAt,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startAt: startAt,
    endAt: startAt.add(const Duration(hours: 1)),
    allDay: false,
    category: EventCategory.basic,
    colorValue: EventCategory.basic.colorValue,
    createdAt: startAt,
    updatedAt: startAt,
  );
}
