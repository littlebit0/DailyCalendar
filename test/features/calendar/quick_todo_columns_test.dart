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

  test('a wrapped title makes a card taller than the same count of short ones', () {
    final shortRows = quickTodoCardHeight(List.filled(10, 1));
    final wrappedRows = quickTodoCardHeight(List.filled(10, 2));
    expect(wrappedRows, greaterThan(shortRows));
    // Each row is at least as tall as its checkbox.
    expect(quickTodoCardHeight([1]), greaterThanOrEqualTo(44 + 48));
    expect(quickTodoCardHeight(const []), 44);
  });

  test('placement follows rendered height, not event count', () {
    // Card A has 20 events that all wrap; card B has 21 single-line events.
    // A is the taller card, so the third card goes under B.
    final a = quickTodoCardHeight(List.filled(20, 2));
    final b = quickTodoCardHeight(List.filled(21, 1));
    expect(a, greaterThan(b));
    expect(assignQuickTodoColumns([a, b, 100], 2), [
      [0],
      [1, 2],
    ]);
    // By count alone B (21) would have looked taller than A (20).
    expect(assignQuickTodoColumns([20, 21, 100], 2), [
      [0, 2],
      [1],
    ]);
  });
}
