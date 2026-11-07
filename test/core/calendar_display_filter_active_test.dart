import 'package:daily/core/calendar/event_display_filter.dart';
import 'package:daily/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final defaults = AppSettings();

  test('inactive only when no display condition applies', () {
    expect(calendarDisplayFilterActive(defaults, ''), isFalse);
    expect(calendarDisplayFilterActive(defaults, '   '), isFalse);
  });

  test('search alone stays active', () {
    expect(calendarDisplayFilterActive(defaults, '회의'), isTrue);
  });

  test('each non-search filter is active without a search query', () {
    expect(
      calendarDisplayFilterActive(
        defaults.copyWith(hiddenCategoryIds: ['basic']),
        '',
      ),
      isTrue,
    );
    expect(
      calendarDisplayFilterActive(
        defaults.copyWith(calendarDdayOnly: true),
        '',
      ),
      isTrue,
    );
    expect(
      calendarDisplayFilterActive(
        defaults.copyWith(calendarShowHolidays: false),
        '',
      ),
      isTrue,
    );
  });

  test('clearing search keeps other filters active', () {
    final settings = defaults.copyWith(
      hiddenCategoryIds: ['basic'],
      calendarDdayOnly: true,
    );
    expect(calendarDisplayFilterActive(settings, '회의'), isTrue);
    expect(calendarDisplayFilterActive(settings, ''), isTrue);
  });

  test('hidden ids of missing categories do not count', () {
    expect(
      calendarDisplayFilterActive(
        defaults.copyWith(hiddenCategoryIds: ['deleted-category']),
        '',
      ),
      isFalse,
    );
  });
}
