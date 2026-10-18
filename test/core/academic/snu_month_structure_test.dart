import 'dart:io';

import 'package:daily/core/academic/snu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

String academic(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();

void main() {
  group('SNU', () {
    final body = academic('snu-2026.html');

    test('repeated or out-of-window sections are rejected', () {
      expect(
        () => SnuAcademicSource.parse(
          body.replaceFirst('<span class="month-text">4월</span>', '<span class="month-text">3월</span>'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SnuAcademicSource.parse(
          body.replaceFirst('<span class="month-text">4월</span>', '<span class="month-text">1월</span>'),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SnuAcademicSource.parse(
          body.replaceFirst('2027년 1월', '2028년 1월'),
          2026,
        ),
        throwsFormatException,
      );
    });

    test('an omitted month is not treated as damage (omission policy unobserved)', () {
      final start = body.indexOf('<div class="work-wrap">', body.indexOf('4월') - 400);
      final next = body.indexOf('<div class="work-wrap">', start + 10);
      final withoutApril = body.replaceRange(start, next, '');
      final events = SnuAcademicSource.parse(withoutApril, 2026);
      expect(events, isNotEmpty);
      expect(events.length, lessThan(SnuAcademicSource.parse(body, 2026).length));
    });
  });
}
