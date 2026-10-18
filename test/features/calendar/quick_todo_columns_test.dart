import 'package:daily/features/calendar/presentation/month_calendar_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a short card is followed by the next card instead of leaving a gap',
    () {
      // A has 2 events, B 10, C 3: C goes under A, not below B's row.
      expect(assignQuickTodoColumns([2, 10, 3], 2), [
        [0, 2],
        [1],
      ]);
    },
  );

  test('every card is placed once and in category order within a column', () {
    final counts = [4, 1, 0, 7, 2, 2, 9];
    final placement = assignQuickTodoColumns(counts, 3);
    final flat = placement.expand((column) => column).toList()..sort();
    expect(flat, [for (var i = 0; i < counts.length; i++) i]);
    for (final column in placement) {
      expect(column, [...column]..sort());
    }
  });

  test('one column keeps the original order and zero cards is empty', () {
    expect(assignQuickTodoColumns([3, 1, 2], 1), [
      [0, 1, 2],
    ]);
    expect(assignQuickTodoColumns(const [], 2), [<int>[], <int>[]]);
  });
}
