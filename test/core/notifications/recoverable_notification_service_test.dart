import 'dart:async';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/notifications/recoverable_notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../../support/persistence_failure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PersistenceFailureStore store;
  late SettingsRepository settings;
  late _Notifications native;
  late RecoverableNotificationService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PersistenceFailureStore();
    SharedPreferencesStorePlatform.instance = store;
    settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    native = _Notifications();
    service = RecoverableNotificationService(native, settings);
  });
  test(
    'individual failure does not skip other events or briefing; restart retries',
    () async {
      native.fail.add('a');
      expect(await service.prepareForReset([event('a'), event('b')]), isFalse);
      expect(native.calls, containsAll(['cancel:a', 'cancel:b', 'briefing']));
      final journal = settings.notificationCleanupJournal!;
      expect(journal, contains('a'));
      expect(journal, isNot(contains('private title')));
      final restarted = RecoverableNotificationService(
        _Notifications(),
        settings,
      );
      await restarted.initialize();
      expect(settings.notificationCleanupJournal, isNull);
    },
  );
  test('journal storage failure prevents reporting a prepared reset', () async {
    store.failureKey = 'flutter.notificationCleanup.v1';
    await expectLater(service.prepareForReset([event('a')]), throwsStateError);
    expect(native.calls, isEmpty);
  });
  test(
    'timeout retains queue ownership and durable journal before new schedule',
    () async {
      native.block = Completer<void>();
      expect(
        await service.prepareForReset([
          event('same'),
        ], timeout: const Duration(milliseconds: 10)),
        isFalse,
      );
      expect(settings.notificationCleanupJournal, isNotNull);
      final schedule = service.scheduleEventReminder(event('same'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(native.calls, isNot(contains('schedule:same')));
      native.block!.complete();
      await schedule;
      expect(native.calls.last, 'schedule:same');
      expect(settings.notificationCleanupJournal, isNull);
    },
  );
  test(
    'failed cleanup prevents new account notification replacement',
    () async {
      native.fail.add('same');
      expect(await service.prepareForReset([event('same')]), isFalse);
      await expectLater(
        service.scheduleEventReminder(event('same')),
        throwsStateError,
      );
      expect(native.calls, isNot(contains('schedule:same')));
      native.fail.clear();
      await service.scheduleEventReminder(event('same'));
      expect(native.calls.last, 'schedule:same');
    },
  );
}

CalendarEvent event(String id) => CalendarEvent(
  id: id,
  title: 'private title',
  startAt: DateTime(2026),
  endAt: DateTime(2026, 1, 1, 1),
  allDay: false,
  category: EventCategory.basic,
  colorValue: 0,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  reminderMinutesBeforeList: [17],
);

class _Notifications implements NotificationService {
  final calls = <String>[];
  final fail = <String>{};
  Completer<void>? block;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> cancelEventReminder(
    String eventId, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {
    calls.add('cancel:$eventId');
    await block?.future;
    if (fail.contains(eventId)) throw StateError('OS unavailable');
  }

  @override
  Future<void> cancelMorningBriefing() async {
    calls.add('briefing');
  }

  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {
    calls.add('schedule:${event.id}');
  }

  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<int> pendingNotificationCount() async => 0;
  @override
  Future<String> permissionSummary() async => '';
}
