import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:flutter_test/flutter_test.dart';

bool changed({
  String initialQuery = '',
  String finalQuery = '',
  List<String> initialHidden = const [],
  List<String> finalHidden = const [],
  bool initialHolidays = true,
  bool finalHolidays = true,
  bool initialDday = false,
  bool finalDday = false,
}) => filterSheetChangedSettings(
  initialQuery: initialQuery,
  finalQuery: finalQuery,
  initialHiddenCategoryIds: initialHidden,
  finalHiddenCategoryIds: finalHidden,
  initialShowHolidays: initialHolidays,
  finalShowHolidays: finalHolidays,
  initialDdayOnly: initialDday,
  finalDdayOnly: finalDday,
);

void main() {
  test('closing the filter sheet untouched is not an applied filter', () {
    expect(changed(), isFalse);
    expect(
      changed(initialHidden: ['a', 'b'], finalHidden: ['b', 'a']),
      isFalse,
      reason: 'order of hidden categories does not matter',
    );
    expect(changed(initialQuery: ' x ', finalQuery: 'x'), isFalse);
  });

  test('any real change counts as applied', () {
    expect(changed(finalQuery: 'exam'), isTrue);
    expect(changed(finalHidden: ['work']), isTrue);
    expect(changed(initialHidden: ['work']), isTrue);
    expect(changed(finalHolidays: false), isTrue);
    expect(changed(finalDday: true), isTrue);
  });

  test('toggling back to the original state is not applied', () {
    expect(
      changed(initialHidden: ['work'], finalHidden: ['work']),
      isFalse,
    );
    expect(changed(initialDday: true, finalDday: true), isFalse);
  });
}
