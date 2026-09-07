import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to leading title alignment and persists center', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    expect(
      repository.load().calendarEventTitleAlignment,
      CalendarEventTitleAlignment.leading,
    );

    await repository.save(
      repository.load().copyWith(
        calendarEventTitleAlignment: CalendarEventTitleAlignment.center,
      ),
      markSyncPending: false,
    );

    expect(
      repository.load().calendarEventTitleAlignment,
      CalendarEventTitleAlignment.center,
    );
  });

  test('defaults to calendar start screen and persists quick view', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);

    expect(repository.load().appStartView, AppStartView.calendar);

    await repository.save(
      repository.load().copyWith(appStartView: AppStartView.quickView),
      markSyncPending: false,
    );

    expect(repository.load().appStartView, AppStartView.quickView);
  });

  test('persists category order and event sort priority', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    const work = EventCategory(id: 'work', label: '업무', colorValue: 0xff2563eb);

    await repository.save(
      repository.load().copyWith(
        categories: [EventCategory.holiday, work, EventCategory.basic],
        calendarEventSortPriority: CalendarEventSortPriority.category,
      ),
      markSyncPending: false,
    );

    final restored = repository.load();
    expect(restored.categories.map((category) => category.id), [
      'holiday',
      'work',
      'basic',
    ]);
    expect(
      restored.calendarEventSortPriority,
      CalendarEventSortPriority.category,
    );
  });

  test('persists and merges date-specific manual event order', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final older = CalendarManualEventOrder(
      eventKeys: const ['first', 'second'],
      updatedAt: DateTime.utc(2026, 8, 21, 1),
      deviceId: 'device-a',
    );
    final newer = CalendarManualEventOrder(
      eventKeys: const ['second', 'first'],
      updatedAt: DateTime.utc(2026, 8, 21, 2),
      deviceId: 'device-b',
    );

    await repository.save(
      repository.load().copyWith(
        calendarManualEventOrders: {'2026-08-21': older},
      ),
      markSyncPending: false,
    );

    final restored = repository.load().calendarManualEventOrders['2026-08-21'];
    expect(restored?.eventKeys, ['first', 'second']);
    expect(restored?.updatedAt, older.updatedAt.toLocal());

    final merged = mergeCalendarManualEventOrders(
      {'2026-08-21': older},
      {'2026-08-21': newer},
    );
    expect(merged['2026-08-21']?.eventKeys, ['second', 'first']);
  });
}
