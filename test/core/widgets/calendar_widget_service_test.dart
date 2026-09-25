import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/widgets/calendar_widget_service.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    });
  }

  test(
    'school visibility grant uses verified time and clears during refresh',
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
      visible = false;
      verified = null;
      await service.refresh(now: now);
      expect(snapshots.last['todayEvents'], isEmpty);
      expect((snapshots.last['lmsVisibility'] as Map)['eventIds'], isEmpty);
      expect((snapshots.last['lmsVisibility'] as Map)['checkedAt'], isNull);
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
