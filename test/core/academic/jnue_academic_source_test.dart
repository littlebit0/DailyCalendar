import 'dart:io';
import 'package:daily/core/academic/jnue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = File('test/fixtures/academic/jnue-2026.html').readAsStringSync();
  test(
    'official fourteen-month document preserves dated events, not blank dates',
    () {
      final events = JnueAcademicSource.parse(
        body,
        2026,
        'https://www.jnue.kr/',
      );
      expect(events, hasLength(41));
      final practice = events.singleWhere((e) => e.title == '4학년 실무실습');
      expect(practice.start, DateTime(2026, 5, 18));
      expect(practice.end, DateTime(2026, 6, 13));
      final sports = events.singleWhere((e) => e.title == '황학구기대회');
      expect(sports.start, DateTime(2026, 3, 16));
      expect(sports.end, DateTime(2026, 5, 31));
      expect(events.where((e) => e.title.contains('학위논문대체과정')), isEmpty);
      expect(events.where((e) => e.start.year != 2026), isEmpty);
      expect(
        events.singleWhere((e) => e.title == '2025-2 계절제 개강').start,
        DateTime(2026, 1, 8),
      );
    },
  );
  test(
    'latest annual publication selected; stale year and incomplete pair rejected',
    () {
      final notices = File(
        'test/fixtures/academic/jnue-notices.json',
      ).readAsStringSync();
      expect(
        JnueAcademicSource.selectDocument(notices, 2026),
        '2026021919c74234d0a65',
      );
      expect(
        () => JnueAcademicSource.selectDocument(notices, 2030),
        throwsFormatException,
      );
      expect(
        () => JnueAcademicSource.parse(body, 2027, 'https://www.jnue.kr/'),
        throwsFormatException,
      );
      expect(
        () => JnueAcademicSource.parse(
          body.replaceFirst('18~6.12', '18~6.99'),
          2026,
          'https://www.jnue.kr/',
        ),
        throwsFormatException,
      );
    },
  );
}
