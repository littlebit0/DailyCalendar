import 'dart:io';

import 'package:daily/core/academic/unist_academic_source.dart';
import 'package:daily/core/academic/seoultech_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'UNIST preserves winter vacation and excludes events outside requested year',
    () {
      final body = File(
        'test/fixtures/academic/unist-2026.json',
      ).readAsStringSync();
      final events = UnistAcademicSource.parse(body, 2026);
      expect(events.length, 63);
      final winter = events.singleWhere((e) => e.sourceId == '603');
      expect(winter.start, DateTime(2025, 12, 20));
      expect(winter.end, DateTime(2026, 3, 2));
      expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(
        () => UnistAcademicSource.parse(
          body.replaceFirst('2025-12-20', '2025-12-32'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'Seoultech imports student academic events, excludes finance office records, never repairs dates',
    () {
      final invalid = File(
        'test/fixtures/academic/seoultech-2025-2.html',
      ).readAsStringSync();
      expect(invalid, contains('2026.01.29 ~ 01.19'));
      final previous = SeoultechAcademicSource.parse(invalid, 2025, 2);
      expect(previous.any((e) => e.title.contains('회계연도')), isFalse);
      expect(previous.any((e) => e.title.contains('동계')), isTrue);
      expect(
        () => SeoultechAcademicSource.parse(
          invalid.replaceFirst('2026회계연도 본예산 재정위원회 제출', '2026학년도 수강신청'),
          2025,
          2,
        ),
        throwsFormatException,
      );
      final first = SeoultechAcademicSource.parse(
        File('test/fixtures/academic/seoultech-2026-1.html').readAsStringSync(),
        2026,
        1,
      );
      expect(first.any((e) => e.title == '2026학년도 1학기 개시 및 개강'), isTrue);
      final second = SeoultechAcademicSource.parse(
        File('test/fixtures/academic/seoultech-2026-2.html').readAsStringSync(),
        2026,
        2,
      );
      expect(second.any((e) => e.start.year == 2027), isTrue);
    },
  );
}
