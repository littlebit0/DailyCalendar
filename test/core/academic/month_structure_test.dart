import 'package:daily/core/academic/month_structure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requireTwelveMonths', () {
    final all = [for (var m = 1; m <= 12; m++) '$m월'];
    test('accepts each month once, with or without trailing text', () {
      requireTwelveMonths(all, 'X');
      requireTwelveMonths([for (var m = 1; m <= 12; m++) ' $m월 MONTH '], 'X');
    });
    test('rejects missing, repeated, extra and malformed headings', () {
      expect(
        () => requireTwelveMonths(all.take(11), 'X'),
        throwsFormatException,
      );
      expect(
        () => requireTwelveMonths([...all.take(11), '1월'], 'X'),
        throwsFormatException,
      );
      expect(
        () => requireTwelveMonths([...all, '5월'], 'X'),
        throwsFormatException,
      );
      expect(
        () => requireTwelveMonths([...all.take(11), '13월'], 'X'),
        throwsFormatException,
      );
      expect(
        () => requireTwelveMonths([...all.take(11), 'April'], 'X'),
        throwsFormatException,
      );
    });
  });
}
