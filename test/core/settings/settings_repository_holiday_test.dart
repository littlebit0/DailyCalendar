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

  test('exposes the removed overnight setting only to seed events', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    expect(
      SettingsRepository(
        preferences: preferences,
      ).legacyShowOvernightOnFollowingDays(),
      isTrue,
    );
    await preferences.setBool(
      'calendarShowOvernightEventsOnFollowingDays',
      false,
    );
    final repository = SettingsRepository(preferences: preferences);
    expect(repository.legacyShowOvernightOnFollowingDays(), isFalse);
    // The app-wide value is no longer part of the synchronized settings.
    expect(
      repository.settingsSyncDocument().fields,
      isNot(contains('calendarShowOvernightEventsOnFollowingDays')),
    );
  });
}
