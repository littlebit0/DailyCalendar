import 'dart:io';
import 'package:daily/core/academic/pnu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(int year, String term) =>
    File('test/fixtures/academic/pnu-$year-$term.html').readAsStringSync();
void main() {
  test(
    'PNU official terms preserve complete winter periods and valid dates',
    () {
      final events = [
        ...PnuAcademicSource.parse(fixture(2025, '0020'), 2025, '0020'),
        ...PnuAcademicSource.parse(fixture(2026, '0010'), 2026, '0010'),
        ...PnuAcademicSource.parse(fixture(2026, '0020'), 2026, '0020'),
      ];
      final winter = events.where((e) => e.title == '겨울계절수업 강의시작종료일').toList();
      expect(
        winter.any(
          (e) =>
              e.start == DateTime(2025, 12, 22) &&
              e.end == DateTime(2026, 1, 20),
        ),
        isTrue,
      );
      expect(
        winter.any(
          (e) =>
              e.start == DateTime(2026, 12, 24) &&
              e.end == DateTime(2027, 1, 22),
        ),
        isTrue,
      );
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('PNU rejects mismatched selected year or term and incomplete table', () {
    final body = fixture(2026, '0020');
    expect(
      () => PnuAcademicSource.parse(body, 2025, '0020'),
      throwsFormatException,
    );
    expect(
      () => PnuAcademicSource.parse(body, 2026, '0010'),
      throwsFormatException,
    );
    expect(
      () => PnuAcademicSource.parse(
        body.replaceFirst('id="resultTbody"', 'id="missing"'),
        2026,
        '0020',
      ),
      throwsFormatException,
    );
  });
  test('PNU rejects invalid calendar dates instead of rolling them over', () {
    final body = fixture(2026, '0020');
    expect(body, contains('2026-04-24'));
    expect(
      () => PnuAcademicSource.parse(
        body.replaceFirst('2026-04-24', '2026-02-30'),
        2026,
        '0020',
      ),
      throwsFormatException,
    );
  });
}
