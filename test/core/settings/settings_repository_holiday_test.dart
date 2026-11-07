import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists a custom holiday color and background preference', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    final holiday = EventCategory.holiday.copyWith(colorValue: 0xff10b981);

    await repository.save(
      repository.load().copyWith(
        categories: [EventCategory.basic, holiday],
        calendarHolidayBackgroundEnabled: false,
      ),
      markSyncPending: false,
    );

    final restored = repository.load();
    final restoredHoliday = restored.categories.singleWhere(
      (category) => category.id == EventCategory.holiday.id,
    );
    expect(restoredHoliday.colorValue, 0xff10b981);
    expect(restoredHoliday.locked, isTrue);
    expect(restored.calendarHolidayBackgroundEnabled, isFalse);
  });

  test('keeps showing overnight events by default and persists off', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences: preferences);
    // Upgrading users keep the previous every-overlapped-date listing.
    expect(
      repository.load().calendarShowOvernightEventsOnFollowingDays,
      isTrue,
    );

    await repository.save(
      repository.load().copyWith(
        calendarShowOvernightEventsOnFollowingDays: false,
      ),
      markSyncPending: false,
    );

    expect(
      SettingsRepository(
        preferences: preferences,
      ).load().calendarShowOvernightEventsOnFollowingDays,
      isFalse,
    );
  });
}
