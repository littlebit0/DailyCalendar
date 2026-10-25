import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/koreatech_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/koreatech-$year.html').readAsStringSync();
void main() {
  test(
    'Koreatech academic year combines preceding winter and full periods',
    () async {
      final source = KoreatechAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/board.es');
          expect(request.url.queryParameters['bid'], '0006');
          final year = int.parse(
            request.url.queryParameters['sel_date']!.substring(0, 4),
          );
          return http.Response(
            fixture(year),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      final winter = events
          .where((e) => e.title.startsWith('동계 계절수업('))
          .toList();
      expect(winter.map((e) => (e.start, e.end)), [
        (DateTime(2025, 12, 22), DateTime(2026, 1, 14)),
        (DateTime(2026, 12, 21), DateTime(2027, 1, 13)),
      ]);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('every published Koreatech row is imported for each year', () {
    // Periods spanning months are repeated in every month they touch, and
    // 2026 repeats one row twice per month; each distinct row is one event.
    for (final (year, published, distinct) in [
      (2025, 82, 72),
      (2026, 90, 79),
    ]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.lst table tbody > tr')
          .map(
            (row) => row
                .querySelectorAll('td')
                .map((cell) => cell.text.replaceAll(RegExp(r'\s+'), ' ').trim())
                .join('|'),
          )
          .toList();
      expect(rows, hasLength(published));
      expect(rows.toSet(), hasLength(distinct));
      final events = KoreatechAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(distinct));
      for (final row in rows.toSet()) {
        final title = row.split('|').last;
        expect(events.where((e) => e.title == title), isNotEmpty, reason: row);
      }
    }
  });
  test('Koreatech profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000189',
      'academyinfo:0000189',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국기술교육대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'koreatech',
      );
    }
  });
  test('Koreatech rejects missing months and wrong year', () {
    expect(
      () => KoreatechAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => KoreatechAcademicSource.parse(
        fixture(2026).replaceFirst('CalendarList', 'missing'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
