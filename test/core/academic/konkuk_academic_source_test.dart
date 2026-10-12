import 'dart:io';
import 'package:daily/core/academic/konkuk_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fixture(String name) =>
      File('test/fixtures/academic/$name').readAsStringSync();
  test(
    'Seoul annual dates retain whole winters and strict numeric boundaries',
    () {
      final previous = KonkukAcademicSource.parseSeoul(
        fixture('konkuk-2025.html'),
        2025,
      );
      final events = KonkukAcademicSource.parseSeoul(
        fixture('konkuk-2026.html'),
        2026,
      );
      expect(events, hasLength(34));
      final winter = previous.singleWhere((e) => e.title == '동계 계절학기');
      expect(winter.start, DateTime(2025, 12, 22));
      expect(winter.end, DateTime(2026, 1, 16));
      expect(
        events.singleWhere((e) => e.title.contains('동계 계절학기')).end,
        DateTime(2027, 1, 15),
      );
      expect(
        () =>
            KonkukAcademicSource.parseSeoul(fixture('konkuk-2026.html'), 2025),
        throwsFormatException,
      );
    },
  );
  test(
    'GLOCAL preserves previous vacation and its separately published seasonal periods',
    () {
      final annual = KonkukAcademicSource.parseGlocal(
        fixture('konkuk-glocal-2026.json'),
        2026,
      );
      expect(annual, hasLength(14));
      expect(
        annual
            .singleWhere((e) => e.title == '동계방학' && e.start.year == 2025)
            .start,
        DateTime(2025, 12, 20),
      );
      expect(
        annual
            .singleWhere((e) => e.title == '동계방학' && e.start.year == 2025)
            .end,
        DateTime(2026, 3, 3),
      );
      final winter = KonkukAcademicSource.parseSupplement(
        fixture('konkuk-glocal-winter-notices.json'),
        2025,
        winter: true,
        host: 'formativeart.kku.ac.kr',
        menu: '160',
        site: '38',
        board: '3',
      ).single;
      expect(winter.start, DateTime(2025, 12, 22));
      expect(winter.end, DateTime(2026, 1, 15));
      final summer = KonkukAcademicSource.parseSupplement(
        fixture('konkuk-glocal-summer-notices.json'),
        2026,
        winter: false,
        host: 'www.kku.ac.kr',
        menu: '1740',
        site: '2',
        board: '18',
      ).single;
      expect(summer.start, DateTime(2026, 6, 23));
      expect(summer.end, DateTime(2026, 7, 15));
      expect(
        () => KonkukAcademicSource.parseSupplement(
          fixture('konkuk-glocal-winter-notices.json'),
          2026,
          winter: true,
          host: 'formativeart.kku.ac.kr',
          menu: '160',
          site: '38',
          board: '3',
        ),
        throwsFormatException,
      );
    },
  );
}
