import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/konkuk_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/$name').readAsStringSync();

http.Response ok(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'text/html;charset=utf-8'},
);

void main() {
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
      expect(
        () => KonkukAcademicSource.parseSeoul(
          fixture('konkuk-2026.html').replaceFirst('02.20', '02.30'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );

  test('Seoul fetch keeps previous winter rows that reach the year', () async {
    final requested = <String>[];
    final source = KonkukAcademicSource(
      client: MockClient((r) async {
        expect(r.url.host, 'www.konkuk.ac.kr');
        expect(r.url.path, '/schdulmanage/konkuk/23/yearSchdul.do');
        final year = Uri.splitQueryString(r.body)['year']!;
        requested.add(year);
        return ok(fixture('konkuk-$year.html'));
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, ['2025', '2026']);
    // 34 rows of 2026 plus the 2025 winter vacation and winter session.
    expect(events, hasLength(36));
    expect(
      events.any(
        (e) =>
            e.title == '동계방학' &&
            e.start == DateTime(2025, 12, 20) &&
            e.end == DateTime(2026, 2, 27),
      ),
      isTrue,
    );
  });

  test(
    'GLOCAL preserves previous vacation and its separately published seasonal periods',
    () {
      final annual = KonkukAcademicSource.parseGlocal(
        fixture('konkuk-glocal-2026.json'),
        2026,
      );
      expect(annual, hasLength(14));
      final vacation = annual.singleWhere(
        (e) => e.title == '동계방학' && e.start.year == 2025,
      );
      expect(vacation.start, DateTime(2025, 12, 20));
      expect(vacation.end, DateTime(2026, 3, 3));
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

  test(
    'GLOCAL fetch adds only seasonal periods with a published notice',
    () async {
      final source = KonkukAcademicSource.glocal(
        client: MockClient((r) async {
          final body = Uri.splitQueryString(r.body);
          if (r.url.path == '/ajax/FR_SCH_SVC/ScheduleListData.do') {
            expect(r.url.host, 'www.kku.ac.kr');
            return ok(fixture('konkuk-glocal-${body['SCH_YEAR']}.json'));
          }
          expect(r.url.path, '/ajax/FR_SVC/BBSViewList2.do');
          if (r.url.host == 'formativeart.kku.ac.kr') {
            expect(body['SEARCH'], '동계');
            return ok(fixture('konkuk-glocal-winter-notices.json'));
          }
          expect(r.url.host, 'www.kku.ac.kr');
          return ok(
            fixture(
              body['SEARCH'] == '동계'
                  ? 'konkuk-glocal-current-winter-notices.json'
                  : 'konkuk-glocal-summer-notices.json',
            ),
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      // 14 annual rows (2025 feed adds only the same winter vacation) plus the
      // 2025 winter and 2026 summer sessions. The 2026 winter session notice has
      // no published dates yet, so nothing is invented for it.
      expect(events, hasLength(16));
      final sessions = events.where((e) => e.title.endsWith('계절학기')).toList();
      expect(sessions.map((e) => (e.title, e.start, e.end)), [
        ('동계 계절학기', DateTime(2025, 12, 22), DateTime(2026, 1, 15)),
        ('하계 계절학기', DateTime(2026, 6, 23), DateTime(2026, 7, 15)),
      ]);
    },
  );

  test(
    'GLOCAL creates no seasonal session from a notice without dates',
    () async {
      // The archived 2024 winter notice is titled "2024 동계 계절 학기 시행 계획"
      // and publishes its schedule only as attachments (empty body).
      expect(
        KonkukAcademicSource.parseSupplement(
          fixture('konkuk-glocal-winter-notices.json'),
          2024,
          winter: true,
          host: 'formativeart.kku.ac.kr',
          menu: '160',
          site: '38',
          board: '3',
        ),
        isEmpty,
      );
      // A body with dates in an unknown layout still fails rather than being
      // silently dropped.
      final changed = jsonDecode(fixture('konkuk-glocal-winter-notices.json'));
      for (final r in changed['data']['list'] as List) {
        if (r['BBS_SEQ'] == 34368) r['CONTENTS'] = '<p>12.23.~1.14. 운영</p>';
      }
      expect(
        () => KonkukAcademicSource.parseSupplement(
          jsonEncode(changed),
          2024,
          winter: true,
          host: 'formativeart.kku.ac.kr',
          menu: '160',
          site: '38',
          board: '3',
        ),
        throwsFormatException,
      );
      // 2025: the previous winter notice has no dates and no dated 2025 summer
      // notice is on the current board, so the annual rows are returned alone.
      final source = KonkukAcademicSource.glocal(
        client: MockClient((r) async {
          final body = Uri.splitQueryString(r.body);
          if (r.url.path == '/ajax/FR_SCH_SVC/ScheduleListData.do') {
            return ok(fixture('konkuk-glocal-${body['SCH_YEAR']}.json'));
          }
          if (r.url.host == 'formativeart.kku.ac.kr') {
            return ok(fixture('konkuk-glocal-winter-notices.json'));
          }
          return ok(
            fixture(
              body['SEARCH'] == '동계'
                  ? 'konkuk-glocal-current-winter-notices.json'
                  : 'konkuk-glocal-summer-notices.json',
            ),
          );
        }),
      );
      final events = await source.fetch(2025);
      source.close();
      final annual = KonkukAcademicSource.parseGlocal(
        fixture('konkuk-glocal-2025.json'),
        2025,
      );
      expect(
        events.map((e) => e.sourceId).toSet(),
        annual.map((e) => e.sourceId).toSet(),
      );
      expect(events.where((e) => e.title.endsWith('계절학기')), isEmpty);
    },
  );

  test('every published Konkuk row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final seoul = fixture('konkuk-$year.html');
      final seoulRows = html
          .parse(seoul)
          .querySelectorAll('.yearSchdul .list-date')
          .length;
      final seoulEvents = KonkukAcademicSource.parseSeoul(seoul, year);
      expect(seoulEvents, hasLength(seoulRows));
      expect(seoulEvents.map((e) => e.sourceId).toSet(), hasLength(seoulRows));

      final glocal = fixture('konkuk-glocal-$year.json');
      final glocalRows = (jsonDecode(glocal)['data'] as List).length;
      final glocalEvents = KonkukAcademicSource.parseGlocal(glocal, year);
      expect(glocalEvents, hasLength(glocalRows));
      expect(
        glocalEvents.map((e) => e.sourceId).toSet(),
        hasLength(glocalRows),
      );
    }
  });

  test('Konkuk profiles resolve to the calendar of their campus', () {
    String? resolve(String universityId, [String? campusId]) => AcademicProfile(
      universityId: universityId,
      universityName: '건국대학교',
      schoolKind: 'fourYear',
      campusId: campusId,
    ).academicSourceId;
    expect(resolve('institution:academyinfo:0000052'), 'konkuk');
    expect(
      resolve('institution:academyinfo:0000052', 'academyinfo:0000052'),
      'konkuk',
    );
    expect(
      resolve('institution:academyinfo:0000052', 'academyinfo:0000053'),
      'konkuk-glocal',
    );
    expect(resolve('academyinfo:0000052'), 'konkuk');
    expect(resolve('academyinfo:0000053'), 'konkuk-glocal');
  });
}
