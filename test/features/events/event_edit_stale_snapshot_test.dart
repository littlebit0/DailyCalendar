import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/events/domain/event_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late DriftEventRepository repository;
  late EventCommandService commands;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(db);
    commands = EventCommandService(
      repository: repository,
      settingsRepository: SettingsRepository(
        preferences: await SharedPreferences.getInstance(),
      ),
      notificationService: _Notifications(),
      syncService: _Sync(),
    );
  });
  tearDown(() => db.close());

  final snapshot = CalendarEvent(
    id: 'single',
    allDay: false,
    title: '원래 제목',
    startAt: DateTime(2026, 11, 20, 10),
    endAt: DateTime(2026, 11, 20, 11),
    category: EventCategory.other,
    colorValue: EventCategory.other.colorValue,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
    deviceId: 'test',
  );
  // What the editor returns when only the title was changed.
  final draft = EventDraft(
    title: '바꾼 제목',
    startAt: snapshot.startAt,
    endAt: snapshot.endAt,
    reminderMinutesBefore: null,
    categoryChanged: false,
  );
  Future<void> saveEdit() => commands.save(
    draft.applyTo(snapshot),
    preserveCategory: true,
    editDraft: draft,
  );

  test('an edit keeps a completion made while the editor was open', () async {
    await repository.save(snapshot);
    await repository.save(snapshot.copyWith(completed: true));

    await saveEdit();

    final stored = (await repository.findById(snapshot.id))!;
    expect(stored.title, '바꾼 제목');
    expect(stored.completed, isTrue);
    expect(stored.syncStatus, 'pending');
  });

  test('an edit does not revive an event deleted meanwhile', () async {
    await repository.save(snapshot);
    await repository.delete(snapshot.id);

    await expectLater(saveEdit(), throwsA(isA<EventEditTargetGone>()));

    final stored = (await repository.findById(snapshot.id))!;
    expect(stored.isDeleted, isTrue);
    expect(stored.title, '원래 제목');
    expect(stored.syncStatus, 'pending_delete');
  });

  test('an edit of a compacted row is not recreated', () async {
    await expectLater(saveEdit(), throwsA(isA<EventEditTargetGone>()));
    expect(await repository.findById(snapshot.id), isNull);
  });

  test('an unchanged row is edited as before', () async {
    await repository.save(snapshot);

    await saveEdit();

    final stored = (await repository.findById(snapshot.id))!;
    expect(stored.title, '바꾼 제목');
    expect(stored.completed, isFalse);
    expect(stored.startAt, snapshot.startAt);
    expect(stored.createdAt.isAtSameMomentAs(snapshot.createdAt), isTrue);
  });
}

class _Sync implements SyncService {
  @override
  Future<void> start() async {}
  @override
  Future<void> queueEventDelete(String id) async {}
  @override
  Future<void> queueEventUpsert(CalendarEvent event) async {}
  @override
  Future<void> queueSettingsBackup() async {}
}

class _Notifications implements NotificationService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleEventReminder(
    CalendarEvent event, {
    bool allowImmediate = false,
  }) async {}
  @override
  Future<void> cancelEventReminder(
    String id, {
    List<int> reminderMinutesBeforeList = const [],
  }) async {}
  @override
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
  }) async {}
  @override
  Future<void> cancelMorningBriefing() async {}
  @override
  Future<int> pendingNotificationCount() async => 0;
  @override
  Future<String> permissionSummary() async => 'test';
}
