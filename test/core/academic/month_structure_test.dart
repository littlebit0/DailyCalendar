import 'dart:io';

import 'package:daily/core/academic/expansion_a_academic_sources.dart';
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
      expect(() => requireTwelveMonths(all.take(11), 'X'), throwsFormatException);
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

  group('INJE', () {
    final body = File(
      'test/fixtures/expansion_a/inje-cal.html',
    ).readAsStringSync();
    final card = RegExp(
      r'<div class="monthCard">(?:(?!<div class="monthCard">)[\s\S])*?class="monthNum">4월[\s\S]*?</ul>\s*</div>\s*</div>',
    );

    test('an empty month card is kept and accepted', () {
      final match = card.firstMatch(body)!;
      final emptied = match
          .group(0)!
          .replaceAll(RegExp(r'<li>[\s\S]*?</li>'), '');
      final rows = InjeAcademicSource.parse(
        body.replaceFirst(match.group(0)!, emptied),
        2026,
      );
      final original = InjeAcademicSource.parse(body, 2026);
      expect(rows.length, lessThan(original.length));
      expect(rows.any((row) => row.start.month == 4), isFalse);
    });

    test('a missing month card is rejected as damaged', () {
      final match = card.firstMatch(body)!;
      expect(
        () => InjeAcademicSource.parse(
          body.replaceFirst(match.group(0)!, ''),
          2026,
        ),
        throwsFormatException,
      );
    });

    test('a repeated month card is rejected', () {
      final match = card.firstMatch(body)!;
      expect(
        () => InjeAcademicSource.parse(
          body.replaceFirst(match.group(0)!, match.group(0)! * 2),
          2026,
        ),
        throwsFormatException,
      );
    });
  });
}
