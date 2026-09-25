import 'package:daily/core/alarms/alarm_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final operation in [
    'editor',
    'import',
    'completion',
    'other-owner',
    'recover-source',
  ]) {
    test(
      'LMS $operation preserves latest atomic source and personal state',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsRepository(
          preferences: await SharedPreferences.getInstance(),
        );
        await settings.saveGoogleAccount(
          const GoogleAccount(email: 'student@example.com'),
        );
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        final repository = _RacingLmsRepository(database);
        final metadata = LmsEventMetadata(
          schoolId: 'smu',
          ownerId: 'student@example.com',
          lmsUserId: '42',
          courseId: '123',
          courseTitle: '자료구조',
          activityType: 'assignment',
          activityId: '456',
          sourceUrl: 'https://ecampus.smu.ac.kr/mod/assign/view.php?id=456',
          submissionStatus: '미제출',
        );
        final original = _event(
          'lms:race',
          EventCategory.basic,
        ).copyWith(lms: metadata, memo: '원래 메모');
        await repository.save(original);
        final notifications = _CountingNotificationService();
        final alarms = _CountingAlarmService();
        final sync = _CountingSyncService();
        final commands = EventCommandService(
          repository: repository,
          settingsRepository: settings,
          notificationService: notifications,
          alarmService: alarms,
          syncService: sync,
        );
        const personalCategory = EventCategory(
          id: 'personal',
          label: '개인',
          colorValue: 0xff123456,
        );
        final source = original.copyWith(
          title: '최신 학교 제목',
          startAt: DateTime(2099, 9, 1),
          endAt: DateTime(2099, 9, 1),
          updatedAt: DateTime(2099, 8, 1),
          lms: metadata.copyWith(submissionStatus: '제출 완료'),
        );
        if (operation == 'editor') {
          repository.beforeMerge = () =>
              repository.save(source.copyWith(completed: true));
          await commands.save(
            original.copyWith(
              memo: '새 개인 메모',
              category: personalCategory,
              colorValue: personalCategory.colorValue,
              reminderMinutesBeforeList: [10],
              clearLms: true,
            ),
          );
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.endAt, source.endAt);
          expect(result.lms, source.lms);
          expect(result.memo, '새 개인 메모');
          expect(result.category.label, personalCategory.label);
          expect(result.reminderMinutesBeforeList, [10]);
          expect(result.completed, isTrue);
          expect(result.updatedAt.isAfter(source.updatedAt), isTrue);
        } else if (operation == 'import') {
          repository.beforeMerge = () => repository.save(
            original.copyWith(
              memo: '동시에 저장한 개인 메모',
              category: personalCategory,
              colorValue: personalCategory.colorValue,
              completed: true,
              reminderMinutesBeforeList: [15],
            ),
          );
          expect(await commands.importBatch([source]), {source.id});
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.lms, source.lms);
          expect(result.memo, '동시에 저장한 개인 메모');
          expect(result.category.label, personalCategory.label);
          expect(result.reminderMinutesBeforeList, [15]);
          expect(result.completed, isTrue);
        } else if (operation == 'completion') {
          repository.beforeMerge = () => repository.save(source);
          await commands.setCompleted(original, true);
          final result = (await repository.findById(original.id))!;
          expect(result.title, source.title);
          expect(result.startAt, source.startAt);
          expect(result.lms, source.lms);
          expect(result.completed, isTrue);
        } else if (operation == 'recover-source') {
          await repository.save(original.copyWith(clearLms: true));
          expect(await commands.importBatch([source]), {source.id});
          final result = (await repository.findById(original.id))!;
          expect(result.lms, source.lms);
          expect(result.title, source.title);
          expect(result.memo, original.memo);
          expect(result.isVisibleToOwner('student@example.com'), isTrue);
        } else {
          await settings.saveGoogleAccount(
            const GoogleAccount(email: 'other@example.com'),
          );
          await commands.save(original.copyWith(memo: '잘못된 계정'));
          await commands.setCompleted(original, true);
          await commands.delete(original.id);
          final result = (await repository.findById(original.id))!;
          expect(result.memo, original.memo);
          expect(result.completed, isFalse);
          expect(result.isDeleted, isFalse);
          expect(sync.upsertedIds, isEmpty);
          expect(sync.deletedIds, isEmpty);
          expect(notifications.cancelCalls, 0);
          expect(alarms.cancelCalls, 0);
        }
      },
    );
  }
  for (final operation in [
    'import',
    'delete-after-find',
    'delete-after-write',
  ]) {
    test('stale LMS session stops $operation side effects', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var current = true;
      final repository = _GuardedRepository(
        _event('guarded', EventCategory.basic),
      );
      if (operation == 'import') repository.afterSave = () => current = false;
      if (operation == 'delete-after-find') {
        repository.afterFind = () => current = false;
      }
      if (operation == 'delete-after-write') {
        repository.afterDelete = () => current = false;
      }
      final notifications = _CountingNotificationService();
      final alarms = _CountingAlarmService();
      final sync = _CountingSyncService();
      var refreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        alarmService: alarms,
        syncService: sync,
        onEventsChanged: () async => refreshes++,
      );
      if (operation == 'import') {
        var prepareCalls = 0;
        final ids = await service.importBatch(
          [repository.event, repository.event.copyWith(id: 'next')],
          prepare: (event) async {
            prepareCalls++;
            return event;
          },
          isCurrent: () => current,
        );
        expect(ids, {'guarded'});
        expect(prepareCalls, 1);
      } else {
        await service.delete(repository.event.id, isCurrent: () => current);
        expect(
          repository.deleteCalls,
          operation == 'delete-after-find' ? 0 : 1,
        );
      }
      expect(notifications.scheduleCalls, 0);
      expect(notifications.cancelCalls, 0);
      expect(alarms.scheduleCalls, 0);
      expect(alarms.cancelCalls, 0);
      expect(sync.upsertedIds, isEmpty);
      expect(sync.deletedIds, isEmpty);
      expect(refreshes, 0);
    });
  }
  test(
    'category appearance updates skip OS notification rescheduling',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final previous = EventCategory.basic;
      const updated = EventCategory(
        id: 'basic',
        label: '기본 일정',
        colorValue: 0xff123456,
      );
      final affected = [_event('one', previous), _event('two', previous)];
      final repository = _CategoryUpdateRepository(affected);
      final notifications = _CountingNotificationService();
      final sync = _CountingSyncService();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        syncService: sync,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.updateCategoryUsage(previous: previous, updated: updated);

      expect(notifications.cancelCalls, 0);
      expect(notifications.scheduleCalls, 0);
      expect(sync.upsertedIds, ['one', 'two']);
      expect(widgetRefreshes, 1);
    },
  );

  test(
    'Todo completion persists, syncs, and updates scheduled delivery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = _CompletionRepository(
        _event('todo', EventCategory.basic),
      );
      final notifications = _CountingNotificationService();
      final alarms = _CountingAlarmService();
      final sync = _CountingSyncService();
      final analytics = _RecordingAnalytics();
      var widgetRefreshes = 0;
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: notifications,
        alarmService: alarms,
        syncService: sync,
        analytics: analytics,
        onEventsChanged: () async => widgetRefreshes += 1,
      );

      await service.setCompleted(repository.event, true);

      expect(repository.event.completed, isTrue);
      expect(repository.event.syncStatus, 'pending');
      expect(notifications.cancelCalls, 1);
      expect(notifications.scheduleCalls, 0);
      expect(alarms.cancelCalls, 1);
      expect(alarms.scheduleCalls, 0);

      await service.setCompleted(repository.event, false);

      expect(repository.event.completed, isFalse);
      expect(notifications.cancelCalls, 2);
      expect(notifications.scheduleCalls, 1);
      expect(alarms.cancelCalls, 2);
      expect(alarms.scheduleCalls, 1);
      expect(sync.upsertedIds, ['todo', 'todo']);
      expect(widgetRefreshes, 2);
      expect(
        analytics.records.map((record) => record.attributes['operation']),
        ['complete', 'uncomplete'],
      );
    },
  );

  test(
    'Todo completion changes only the selected event with a shared title',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = _event(
        'first',
        EventCategory.basic,
      ).copyWith(title: '같은 제목');
      final second = _event(
        'second',
        EventCategory.basic,
      ).copyWith(title: '같은 제목', startAt: DateTime(2026, 7, 30, 9));
      final repository = _MultiCompletionRepository([first, second]);
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: _CountingNotificationService(),
        alarmService: _CountingAlarmService(),
        syncService: _CountingSyncService(),
      );

      await service.setCompleted(first, true);

      expect(repository.events['first']?.completed, isTrue);
      expect(repository.events['second']?.completed, isFalse);
    },
  );

  test(
    'Todo completion detaches only the selected recurring occurrence',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final source = _event('series', EventCategory.basic).copyWith(
        title: '반복 제목',
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 3,
        ),
      );
      final occurrenceStart = source.startAt.add(const Duration(days: 1));
      final occurrence = source.copyWith(
        occurrenceId: 'series@${occurrenceStart.toIso8601String()}',
        startAt: occurrenceStart,
        endAt: occurrenceStart.add(const Duration(hours: 1)),
      );
      final repository = _MultiCompletionRepository([source]);
      final sync = _CountingSyncService();
      final service = EventCommandService(
        repository: repository,
        settingsRepository: SettingsRepository(preferences: preferences),
        notificationService: _CountingNotificationService(),
        alarmService: _CountingAlarmService(),
        syncService: sync,
      );

      await service.setCompleted(occurrence, true);

      final updatedSeries = repository.events['series']!;
      final detached = repository.events.values.singleWhere(
        (event) => event.id != 'series',
      );
      expect(updatedSeries.completed, isFalse);
      expect(updatedSeries.recurrence.excludes(occurrenceStart), isTrue);
      expect(detached.title, '반복 제목');
      expect(detached.startAt, occurrenceStart);
      expect(detached.completed, isTrue);
      expect(detached.occurrenceId, isNull);
      expect(detached.recurrence.isRepeating, isFalse);
      expect(sync.upsertedIds, containsAll(<String>['series', detached.id]));
    },
  );

  test('analytics failure never changes an event command result', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _CompletionRepository(
      _event('isolated', EventCategory.basic),
    );
    final service = EventCommandService(
      repository: repository,
      settingsRepository: SettingsRepository(preferences: preferences),
      notificationService: _CountingNotificationService(),
      alarmService: _CountingAlarmService(),
      syncService: _CountingSyncService(),
      analytics: const _ThrowingAnalytics(),
    );

    await service.setCompleted(repository.event, true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.event.completed, isTrue);
  });
}

CalendarEvent _event(String id, EventCategory category) {
  final start = DateTime(2026, 7, 29, 9);
  return CalendarEvent(
    id: id,
    title: id,
    startAt: start,
    endAt: start.add(const Duration(hours: 1)),
    allDay: false,
    category: category,
    colorValue: category.colorValue,
    createdAt: start,
    updatedAt: start,
  );
}

class _CategoryUpdateRepository implements EventRepository {
  _CategoryUpdateRepository(this.affected);

  final List<CalendarEvent> affected;

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async {
    return affected
        .map(
          (event) => event.copyWith(
            category: updated,
            colorValue: updated.colorValue,
            updatedAt: updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => const [];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => const [];

  @override
  Future<CalendarEvent?> findById(String id) async => null;

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => const [];

  @override
  Future<void> save(CalendarEvent event) async {}

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {}

  @override
  Future<List<CalendarEvent>> search(String query) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => const Stream.empty();
}

class _CountingNotificationService implements NotificationService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    cancelCalls += 1;
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    scheduleCalls += 1;
  }

  @override
  Future<void> cancelMorningBriefing() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<int> pendingNotificationCount() async => 0;

  @override
  Future<String> permissionSummary() async => '';

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
}

class _CountingAlarmService implements AlarmService {
  var cancelCalls = 0;
  var scheduleCalls = 0;

  @override
  Future<AlarmAuthorizationState> authorizationState() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> cancelAllEventAlarms() async {}

  @override
  Future<void> cancelEventAlarm(String eventId) async => cancelCalls += 1;

  @override
  Future<AlarmAuthorizationState> requestAuthorization() async =>
      AlarmAuthorizationState.authorized;

  @override
  Future<void> scheduleEventAlarm(CalendarEvent event) async =>
      scheduleCalls += 1;
}

class _CompletionRepository implements EventRepository {
  _CompletionRepository(this.event);

  CalendarEvent event;

  @override
  Future<CalendarEvent?> findById(String id) async =>
      event.id == id ? event : null;

  @override
  Future<void> save(CalendarEvent value) async => event = value;

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> events) async {
    for (final value in events) {
      event = value;
    }
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async => [event];

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String eventId) async {}

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => [event];

  @override
  Future<void> hardDelete(String eventId) async {}

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async => [event];

  @override
  Future<List<CalendarEvent>> search(String query) async => [event];

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value([event]);
}

class _GuardedRepository extends _CompletionRepository {
  _GuardedRepository(super.event);
  void Function()? afterFind;
  void Function()? afterSave;
  void Function()? afterDelete;
  int deleteCalls = 0;

  @override
  Future<CalendarEvent?> findById(String id) async {
    final found = await super.findById(id);
    afterFind?.call();
    return found;
  }

  @override
  Future<void> save(CalendarEvent value) async {
    await super.save(value);
    afterSave?.call();
  }

  @override
  Future<void> delete(String eventId) async {
    deleteCalls++;
    afterDelete?.call();
  }
}

class _RacingLmsRepository extends DriftEventRepository {
  _RacingLmsRepository(super.database);
  Future<void> Function()? beforeMerge;

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async {
    final action = beforeMerge;
    beforeMerge = null;
    await action?.call();
    return super.mergeRestoredEventsAtomically(remoteEvents, resolve: resolve);
  }
}

class _MultiCompletionRepository implements EventRepository {
  _MultiCompletionRepository(Iterable<CalendarEvent> events)
    : events = {for (final event in events) event.id: event};

  final Map<String, CalendarEvent> events;

  @override
  Future<CalendarEvent?> findById(String id) async => events[id];

  @override
  Future<void> save(CalendarEvent event) async {
    events[event.id] = event;
  }

  @override
  Future<void> saveAllAtomically(Iterable<CalendarEvent> values) async {
    for (final event in values) {
      events[event.id] = event;
    }
  }

  @override
  Future<List<CalendarEvent>> allEventsForSync() async =>
      events.values.toList();

  @override
  Future<void> clearAll() async => events.clear();

  @override
  Future<void> delete(String eventId) async => events.remove(eventId);

  @override
  Future<List<CalendarEvent>> eventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) async => events.values.toList();

  @override
  Future<void> hardDelete(String eventId) async => events.remove(eventId);

  @override
  Future<void> markSynced(String eventId) async {}

  @override
  Future<List<EventRestoreMutation>> mergeRestoredEventsAtomically(
    Iterable<CalendarEvent> remoteEvents, {
    required RestoredEventResolver resolve,
  }) async => const [];

  @override
  Future<List<CalendarEvent>> pendingSyncEvents() async =>
      events.values.toList();

  @override
  Future<List<CalendarEvent>> search(String query) async =>
      events.values.toList();

  @override
  Future<List<CalendarEvent>> updateCategoryReferences({
    required EventCategory previous,
    required EventCategory updated,
    required DateTime updatedAt,
  }) async => const [];

  @override
  Stream<List<CalendarEvent>> watchEventsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => Stream.value(events.values.toList());
}

class _CountingSyncService implements SyncService {
  @override
  Future<void> queueSettingsBackup() async {}

  final upsertedIds = <String>[];
  final deletedIds = <String>[];

  @override
  Future<void> queueEventDelete(String eventId) async =>
      deletedIds.add(eventId);

  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {
    upsertedIds.add(event.id);
  }

  @override
  Future<void> start() async {}
}

class _RecordingAnalytics extends NoopProductAnalytics {
  final records = <AnalyticsRecord>[];

  @override
  Future<void> record(AnalyticsRecord record) async => records.add(record);
}

class _ThrowingAnalytics extends NoopProductAnalytics {
  const _ThrowingAnalytics();

  @override
  Future<void> record(AnalyticsRecord record) async {
    throw StateError('analytics unavailable');
  }
}
