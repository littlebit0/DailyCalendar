import 'package:daily/core/settings/app_settings.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // #857: a writer that held a snapshot across a dialog or drag.
  test('updateLatest keeps values stored after the caller took its '
      'snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final stale = repository.load();
    const merged = EventCategory(id: 'merged', label: '병합', colorValue: 1);
    const added = EventCategory(id: 'added', label: '추가', colorValue: 2);
    CalendarManualEventOrder order(String key) => CalendarManualEventOrder(
      eventKeys: [key],
      updatedAt: DateTime.utc(2026, 6, 1),
      deviceId: 'device',
    );
    await repository.save(
      stale.copyWith(
        categories: [...stale.categories, merged],
        calendarManualEventOrders: {'2026-06-01': order('merged')},
      ),
      changedFrom: stale,
    );

    await repository.updateLatest(
      (latest) => latest.copyWith(
        categories: [...latest.categories, added],
        calendarManualEventOrders: {
          ...latest.calendarManualEventOrders,
          '2026-06-02': order('dragged'),
        },
      ),
    );

    final stored = repository.load();
    expect(
      stored.categories.map((c) => c.id),
      containsAll(['merged', 'added']),
    );
    expect(stored.calendarManualEventOrders.keys, {'2026-06-01', '2026-06-02'});
    // Nothing was recorded as removed for the next sync.
    final fields = repository.settingsSyncDocument().fields;
    expect(fields['category/merged/present']?.value, isTrue);
    expect(fields['order/2026-06-01']?.value, isNotNull);
  });
}
