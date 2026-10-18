import 'package:daily/core/notifications/local_notification_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/recurrence_rule.dart';
import 'package:daily/core/notifications/reminder_delivery_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual service protects old colliding owner before cancellation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final time = DateTime.now().add(const Duration(days: 2));
      CalendarEvent event(String id) => CalendarEvent(
        id: id,
        title: id,
        startAt: time,
        endAt: time.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: time,
        updatedAt: time,
        reminderMinutesBeforeList: [0],
      );
      final a = event('98540d8b-c086-46b6-915c-073b7dd24477');
      final b = event('0ff08334-0398-4b7f-866a-ce3a2b6f156f');
      await repository.save(a);
      await repository.save(b);
      final pending = <int, String>{1859504680: b.id};
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('daily/native_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            final args = call.arguments as Map;
            if (call.method == 'schedule') {
              pending[args['id'] as int] = args['payload'] as String;
            }
            if (call.method == 'cancel' || call.method == 'cancelPending') {
              pending.remove(args['id']);
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = LocalNotificationService(
        settingsRepository: settings,
        eventRepository: repository,
      );
      await service.cancelEventReminder(a.id);
      expect(pending.values, contains('${b.id}:reminder:0'));
      expect(pending.containsKey(1859504680), isFalse);
      await service.scheduleEventReminder(a);
      final aID = settings.existingNotificationId('${a.id}:reminder:0')!;
      final bID = settings.existingNotificationId('${b.id}:reminder:0')!;
      expect(aID, isNot(bID));
      expect(pending.keys, containsAll([aID, bID]));
      await service.cancelEventReminder(a.id);
      expect(pending.containsKey(aID), isFalse);
      expect(pending.containsKey(bID), isTrue);
      await service.cancelEventReminder(b.id, includeDelivered: true);
      expect(pending, isEmpty);
    },
  );

  test(
    'repeating event keeps bounded slots and cancel removes every slot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final start = DateTime.now().add(const Duration(days: 1));
      final event = CalendarEvent(
        id: 'daily-series',
        title: '매일',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: start,
        updatedAt: start,
        reminderMinutesBeforeList: [10],
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          count: 20,
        ),
      );
      await repository.save(event);
      final pending = <int, String>{};
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('daily/native_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            final args = call.arguments as Map;
            if (call.method == 'schedule') {
              pending[args['id'] as int] = args['payload'] as String;
            }
            if (call.method == 'cancel' || call.method == 'cancelPending') {
              pending.remove(args['id']);
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = LocalNotificationService(
        settingsRepository: settings,
        eventRepository: repository,
      );
      await service.scheduleEventReminder(event);
      expect(pending, hasLength(recurringReminderSlotsPerOffset));
      expect(pending.values.toSet(), {'daily-series:reminder:10'});
      // Rescheduling reuses the same ids instead of allocating new ones.
      final allocated = settings.notificationIdsWithPrefix('daily-series:');
      await service.scheduleEventReminder(event);
      expect(settings.notificationIdsWithPrefix('daily-series:'), allocated);
      expect(pending, hasLength(recurringReminderSlotsPerOffset));
      // An ended or shortened series drops the slots it no longer needs.
      await service.scheduleEventReminder(
        event.copyWith(
          recurrence: const RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            count: 3,
          ),
        ),
      );
      expect(pending, hasLength(3));
      await service.cancelEventReminder(event.id);
      expect(pending, isEmpty);
    },
  );

  test(
    'chosen zero-minute fallback survives until same-time alarm is confirmed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftEventRepository(database);
      final time = DateTime.now().add(const Duration(days: 2));
      final event = CalendarEvent(
        id: 'alarm-event',
        title: 'alarm',
        startAt: time,
        endAt: time.add(const Duration(hours: 1)),
        allDay: false,
        alarmEnabled: true,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: time,
        updatedAt: time,
        reminderMinutesBeforeList: [0, 10],
      );
      await repository.save(event);
      final pending = <int>{};
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('daily/native_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            final args = call.arguments as Map;
            if (call.method == 'schedule') pending.add(args['id'] as int);
            if (call.method == 'cancel' || call.method == 'cancelPending') {
              pending.remove(args['id']);
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = LocalNotificationService(
        settingsRepository: settings,
        eventRepository: repository,
      );
      await service.scheduleEventReminder(event);
      final zero = settings.existingNotificationId('${event.id}:reminder:0')!;
      final ten = settings.existingNotificationId('${event.id}:reminder:10')!;
      expect(pending, containsAll([zero, ten]));
      await service.confirmAlarmScheduled(event);
      expect(pending, {ten});
      await service.scheduleEventReminder(
        event.copyWith(reminderMinutesBeforeList: [10]),
      );
      expect(pending, {ten});
    },
  );

  test(
    'colliding legacy UUIDs retain unique reminder dday briefing IDs across reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = SettingsRepository(preferences: preferences);
      const a = '98540d8b-c086-46b6-915c-073b7dd24477';
      const b = '0ff08334-0398-4b7f-866a-ce3a2b6f156f';
      int old(String id) => '$id:reminder:0'.codeUnits.fold(
        1000,
        (h, c) => (h * 31 + c) % 2147483648,
      );
      expect(old(a), old(b));
      final keys = [
        '$a:reminder:0',
        '$b:reminder:0',
        '$a:dday:0',
        'briefing:0',
      ];
      final ids = await Future.wait(keys.map(settings.notificationId));
      expect(ids.toSet().length, keys.length);
      expect(ids.every((id) => id < 0), isTrue);
      final reloaded = SettingsRepository(preferences: preferences);
      for (var i = 0; i < keys.length; i++) {
        expect(await reloaded.notificationId(keys[i]), ids[i]);
      }
      expect(reloaded.existingNotificationId('absent'), isNull);
      await reloaded.retireLegacyNotificationIds({old(a)}, delivered: false);
      expect(settings.retiredLegacyNotificationIds(delivered: false), {old(a)});
      expect(settings.retiredLegacyNotificationIds(delivered: true), isEmpty);
    },
  );

  test(
    'corrupt duplicate mapping fails without assigning another owner ID',
    () async {
      SharedPreferences.setMockInitialValues({
        'notificationIds.v2': '{"a":-1,"b":-1}',
      });
      final settings = SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      );
      await expectLater(settings.notificationId('c'), throwsStateError);
    },
  );

  test(
    'separate settings instances serialize allocation over the same store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final a = SettingsRepository(preferences: preferences);
      final b = SettingsRepository(preferences: preferences);
      final ids = await Future.wait(
        List.generate(
          100,
          (i) => (i.isEven ? a : b).notificationId('event:$i'),
        ),
      );
      expect(ids.toSet().length, 100);
    },
  );

  test('iOS shares its 64 pending requests across repeating events', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftEventRepository(database);
    final start = DateTime.now().add(const Duration(days: 1));
    CalendarEvent series(String id, List<int> offsets) => CalendarEvent(
      id: id,
      title: id,
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: start,
      updatedAt: start,
      reminderMinutesBeforeList: offsets,
      recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
    );
    // 9 series x 2 offsets would be 144 requests at 8 slots per offset.
    for (var i = 0; i < 9; i++) {
      await repository.save(series('s$i', [10, 30]));
    }
    final single = start.add(const Duration(days: 2));
    await repository.save(
      CalendarEvent(
        id: 'single',
        title: 'single',
        startAt: single,
        endAt: single.add(const Duration(hours: 1)),
        allDay: false,
        category: EventCategory.basic,
        colorValue: EventCategory.basic.colorValue,
        createdAt: single,
        updatedAt: single,
        reminderMinutesBeforeList: [10],
      ),
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = LocalNotificationService(
      settingsRepository: settings,
      eventRepository: repository,
    );
    final allowance = (await service.repeatingSlotAllowance(settings.load()))!;
    expect(allowance, hasLength(18));
    // 14 briefing days and the single-shot reminder are reserved first.
    expect(allowance.values.fold<int>(0, (a, b) => a + b), 64 - 14 - 1);
    // The soonest occurrences are spread over every series, not one per series.
    expect(allowance.values.every((slots) => slots > 0), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await service.repeatingSlotAllowance(settings.load()), isNull);
  });
}
