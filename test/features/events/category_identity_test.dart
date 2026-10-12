import 'package:daily/core/auth/google_account.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/application/event_command_service.dart';
import 'package:daily/features/events/data/app_database.dart';
import 'package:daily/features/events/data/drift_event_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:daily/core/notifications/notification_service.dart';
import 'package:daily/core/sync/sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const category = EventCategory(
    id: 'custom_stable',
    label: 'Renamed school',
    colorValue: 0xff335577,
  );
  late AppDatabase db;
  late DriftEventRepository repository;
  late EventCommandService commands;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    await settings.saveGoogleAccount(
      const GoogleAccount(email: 'student@example.com'),
    );
    final before = settings.load();
    await settings.save(
      before.copyWith(categories: [...before.categories, category]),
      changedFrom: before,
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftEventRepository(db);
    commands = EventCommandService(
      repository: repository,
      settingsRepository: settings,
      notificationService: _Notifications(),
      syncService: _Sync(),
    );
  });
  tearDown(() => db.close());
  CalendarEvent event() => CalendarEvent(
    id: 'lms:identity',
    allDay: false,
    title: 'School event',
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 9, 1),
    category: category,
    colorValue: category.colorValue,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
    deviceId: 'test',
    lms: LmsEventMetadata(
      schoolId: 'smu',
      ownerId: 'student@example.com',
      lmsUserId: '42',
      courseId: '1',
      courseTitle: 'Course',
      activityType: 'quiz',
      activityId: '2',
      sourceUrl: 'https://ecampus.smu.ac.kr/mod/quiz/view.php?id=2',
    ),
  );

  test(
    'stable category identity survives SQLite reload and source edit',
    () async {
      await repository.save(event());
      final stored = await repository.findById(event().id);
      expect(stored!.category.id, category.id);
      expect(stored.category.label, category.label);
      final row = await db
          .customSelect('SELECT category FROM event_records')
          .getSingle();
      expect(row.read<String>('category'), category.id);
      await commands.save(
        stored.copyWith(memo: 'Updated personal note'),
        preserveCategory: true,
      );
      final reloaded = (await repository.findById(stored.id))!;
      expect(reloaded.category.id, category.id);
      expect(reloaded.memo, 'Updated personal note');
    },
  );

  test(
    'stale editor without category action preserves newer category',
    () async {
      final opened = event();
      await repository.save(opened);
      final newer = category.copyWith(
        id: 'custom_newer',
        label: 'Another category',
      );
      await repository.save(opened.copyWith(category: newer));
      await commands.save(
        opened.copyWith(memo: 'Edit from old dialog'),
        preserveCategory: true,
      );
      expect((await repository.findById(opened.id))!.category.id, newer.id);
    },
  );

  test('explicit category selection is applied', () async {
    await repository.save(event());
    await commands.save(event().copyWith(category: EventCategory.basic));
    expect(
      (await repository.findById(event().id))!.category.id,
      EventCategory.basic.id,
    );
  });

  test('legacy label row remains resolvable after editing', () async {
    await repository.save(event());
    await db.customStatement(
      'UPDATE event_records SET category = ?, sync_timestamp_details = NULL',
      [category.label],
    );
    final legacy = (await repository.findById(event().id))!;
    expect(legacy.category.id, EventCategory.fromStored(category.label).id);
    await commands.save(
      legacy.copyWith(memo: 'Legacy edited'),
      preserveCategory: true,
    );
    expect((await repository.findById(event().id))!.category.id, category.id);
  });

  test('reserved native category cannot match an old custom label', () async {
    await repository.save(
      event().copyWith(category: category.copyWith(label: 'basic')),
    );
    await db.customStatement('UPDATE event_records SET category = ?', [
      'basic',
    ]);
    expect((await repository.findById(event().id))!.category.id, 'basic');
  });

  test(
    'native category change does not revive stale category metadata',
    () async {
      await repository.save(event());
      await db.customStatement('UPDATE event_records SET category = ?', [
        'basic',
      ]);
      expect((await repository.findById(event().id))!.category.id, 'basic');
    },
  );
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
