import 'dart:io';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/expansion17_c_academic_sources.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String school) => File(
  'test/fixtures/academic/$school-expansion17-2026.html',
).readAsStringSync();
void main() {
  final parsers = <String, List<AcademicEvent> Function(String, int)>{
    'nambu': NambuAcademicSource.parse,
    'pcu': PcuAcademicSource.parse,
    'konyang': KonyangAcademicSource.parse,
    'dju': DjuAcademicSource.parse,
  };
  final counts = {'nambu': 71, 'pcu': 73, 'konyang': 49, 'dju': 158};
  for (final school in parsers.keys) {
    test(
      '$school processes the official annual source with date-only exclusive ends',
      () {
        final events = parsers[school]!(fixture(school), 2026);
        expect(events.length, counts[school]);
        expect(
          events.every(
            (event) =>
                event.end.isAfter(event.start) &&
                event.start.hour == 0 &&
                event.end.hour == 0,
          ),
          isTrue,
        );
        expect(events.any((event) => event.title.contains('개강')), isTrue);
        expect(events.any((event) => event.start.month == 12), isTrue);
      },
    );
    test('$school rejects an empty source', () {
      expect(
        () => parsers[school]!('<html></html>', 2026),
        throwsFormatException,
      );
    });
  }
  for (final school in ['pcu', 'konyang', 'dju']) {
    test('$school rejects the wrong selected year', () {
      expect(
        () => parsers[school]!(fixture(school), 2025),
        throwsFormatException,
      );
    });
  }
  test(
    'Nambu refuses invalid published dates rather than overflowing the month',
    () {
      final original = fixture('nambu');
      expect(
        () => NambuAcademicSource.parse(
          original.replaceAll('2026.03.03', '2026.02.30'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'Konyang ignores duplicate mobile month headings and retains academic year rollover',
    () {
      final events = KonyangAcademicSource.parse(fixture('konyang'), 2026);
      expect(events.length, 49);
      expect(events.any((event) => event.start.year == 2027), isTrue);
      expect(events.map((event) => event.sourceId).toSet().length, 49);
    },
  );
  test('DJU duplicate responsive tables have identical event identities', () {
    final events = DjuAcademicSource.parse(fixture('dju'), 2026);
    // 79 monthly rows also repeat five events spanning adjacent months.
    final identities = <String, AcademicEvent>{};
    for (final event in events) {
      final previous = identities[event.sourceId];
      if (previous != null) {
        expect(event.toJson(), previous.toJson());
      }
      identities[event.sourceId] = event;
    }
    expect(identities.length, 74);
    final springGradeEntry = events.where(
      (event) =>
          event.title == '중간시험 성적입력 기간' &&
          event.start == DateTime(2026, 4, 28),
    );
    expect(springGradeEntry.length, 4);
    expect(
      springGradeEntry.every((event) => event.end == DateTime(2026, 5, 7)),
      isTrue,
    );
  });
}
