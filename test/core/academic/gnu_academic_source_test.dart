import 'dart:io';

import 'package:daily/core/academic/gnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GNU reads all undergraduate months with published stable IDs and winter rollover',
    () {
      final body = File(
        'test/fixtures/academic/gnu-2026.json',
      ).readAsStringSync();
      final events = GnuAcademicSource.parse(body, 2026);
      expect(events.length, 50);
      expect(events.map((e) => e.sourceId).toSet().length, 50);
      expect(events.any((e) => e.title.contains('대학원')), isFalse);
      final winter = events.singleWhere((e) => e.sourceId == '13940');
      expect(winter.start, DateTime(2025, 12, 23));
      expect(winter.end, DateTime(2026, 1, 17));
      expect(
        events.singleWhere((e) => e.sourceId == '53779').start,
        DateTime(2026, 3, 3),
      );
    },
  );
  test('GNU refuses stale year and malformed calendar dates', () {
    final body = File(
      'test/fixtures/academic/gnu-2026.json',
    ).readAsStringSync();
    expect(() => GnuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => GnuAcademicSource.parse(
        body.replaceFirst('2025/12/23', '2025/12/32'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
