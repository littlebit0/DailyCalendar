import 'package:daily/core/calendar/korean_holiday_service.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('holiday events use the configured holiday category color', () {
    final category = EventCategory.holiday.copyWith(colorValue: 0xff10b981);
    final events = KoreanHolidayService().holidayEventsInRange(
      DateTime(2026, 8, 15),
      DateTime(2026, 8, 16),
      category: category,
    );

    expect(events, isNotEmpty);
    expect(events.every((event) => event.category == category), isTrue);
    expect(events.every((event) => event.colorValue == 0xff10b981), isTrue);
  });

  group('substitute holidays follow each enforcement date', () {
    final service = KoreanHolidayService();

    bool isSubstitute(DateTime date) => service
        .holidaysInRange(date, date.add(const Duration(days: 1)))
        .any((holiday) => holiday.title.contains('대체공휴일'));

    test('Seollal, Chuseok and Children\'s Day start on 2013-11-05', () {
      expect(isSubstitute(DateTime(2013, 2, 12)), isFalse);
      expect(isSubstitute(DateTime(2013, 5, 6)), isFalse);
      expect(isSubstitute(DateTime(2014, 9, 10)), isTrue);
      expect(isSubstitute(DateTime(2019, 5, 6)), isTrue);
    });

    test('national days start on 2021-08-04', () {
      expect(isSubstitute(DateTime(2020, 10, 5)), isFalse);
      expect(isSubstitute(DateTime(2021, 8, 16)), isTrue);
      expect(isSubstitute(DateTime(2021, 10, 4)), isTrue);
      expect(isSubstitute(DateTime(2021, 10, 11)), isTrue);
    });

    test('Buddha\'s Birthday and Christmas start on 2023-05-04', () {
      expect(isSubstitute(DateTime(2021, 12, 27)), isFalse);
      expect(isSubstitute(DateTime(2022, 5, 9)), isFalse);
      expect(isSubstitute(DateTime(2022, 12, 26)), isFalse);
      expect(isSubstitute(DateTime(2023, 5, 29)), isTrue);
      expect(isSubstitute(DateTime(2027, 12, 27)), isTrue);
    });
  });
}
