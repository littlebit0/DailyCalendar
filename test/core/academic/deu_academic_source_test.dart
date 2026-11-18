import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/deu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(int year) =>
      File('test/fixtures/academic/deu-$year.html').readAsStringSync();
  test(
    'DEU reads two semesters, abbreviated end days and next January',
    () async {
      final requested = <String>[];
      final source = DeuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/www/scheduleList.do');
          final year = request.url.queryParameters['schYear']!;
          requested.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requested, ['2025', '2026']);
      expect(events.length, 66);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winter = events.singleWhere(
        (e) => e.start == DateTime(2026, 12, 28),
      );
      expect(winter.title, '동계계절수업');
      expect(winter.end, DateTime(2027, 1, 19));
      final previousWinter = events.singleWhere(
        (e) => e.start == DateTime(2025, 12, 29),
      );
      expect(previousWinter.end, DateTime(2026, 1, 20));
      final correction = events.singleWhere(
        (e) => e.start == DateTime(2026, 3, 5),
      );
      expect(correction.end, DateTime(2026, 3, 10));
      expect(
        events.any(
          (e) =>
              e.title == '2025학년도 전기 학위 수여식' &&
              e.start == DateTime(2026, 2, 20),
        ),
        isTrue,
      );
      expect(events.any((e) => e.start.year == 2027), isFalse);
    },
  );
  test('every published DEU semester row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('table.tbl-basic-dleft')
          .where(
            (t) =>
                t.querySelector('caption')?.text.trim() ==
                    '$year년 1학기 날짜별 내용으로 구성' ||
                t.querySelector('caption')?.text.trim() ==
                    '$year년 2학기 날짜별 내용으로 구성',
          )
          .expand((t) => t.querySelectorAll('tbody tr'))
          .length;
      expect(rows, year == 2025 ? 59 : 65);
      final events = DeuAcademicSource.parse(fixture(year), year);
      expect(events, hasLength(rows));
      expect(events.every((e) => !e.title.contains('\n')), isTrue);
    }
  });
  test(
    'DEU keeps prior-year January while the next year is unpublished',
    () async {
      // Live 2028 page recorded on 2026-11-19, before 2028 was published.
      final unpublished = File(
        'test/fixtures/academic/deu-2028-unpublished.html',
      ).readAsStringSync();
      expect(
        DeuAcademicSource.parse(unpublished, 2028, allowUnpublished: true),
        isEmpty,
      );
      expect(
        () => DeuAcademicSource.parse(unpublished, 2028),
        throwsFormatException,
      );
      // The notice never stands in for another year's page.
      expect(
        () =>
            DeuAcademicSource.parse(unpublished, 2027, allowUnpublished: true),
        throwsFormatException,
      );
      Future<List<AcademicEvent>> fetch(Map<int, String> pages, int year) {
        final source = DeuAcademicSource(
          client: MockClient((request) async {
            final y = int.parse(request.url.queryParameters['schYear']!);
            return http.Response(
              pages[y]!,
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );
        addTearDown(source.close);
        return source.fetch(year);
      }

      final events = await fetch({
        2027: fixture(2027),
        2028: unpublished,
      }, 2028);
      expect(events, isNotEmpty);
      expect(events.every((e) => e.sourceId.startsWith('2027:')), isTrue);
      expect(
        events.every((e) => e.start.month <= 2 || e.start.year < 2028),
        isTrue,
      );
      expect(events.any((e) => e.start.year == 2028), isTrue);
      // An unpublished prior academic year is still a failure.
      await expectLater(
        fetch({2028: unpublished}, 2029),
        throwsFormatException,
      );
    },
  );

  test('DEU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000107',
      'academyinfo:0000107',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '동의대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'deu',
      );
    }
  });
  test('DEU rejects incorrect year, malformed day and missing semester', () {
    final body = fixture(2026);
    expect(() => DeuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => DeuAcademicSource.parse(body.replaceFirst('3월 1일', '3월 32일'), 2026),
      throwsFormatException,
    );
    expect(
      () => DeuAcademicSource.parse(
        body.replaceFirst('2026년 2학기 날짜별', '2026년 2학기 목록'),
        2026,
      ),
      throwsFormatException,
    );
  });

  test('DEU February-to-March period stays in one calendar year', () {
    final body = fixture(2025);
    final changed = body.replaceFirst('2월 19 ~ 24일', '2월 19 ~ 3월 5일');
    expect(changed, isNot(body));
    final event = DeuAcademicSource.parse(
      changed,
      2025,
    ).singleWhere((e) => e.title == '현금등록, 수강신청');
    expect(event.start, DateTime(2026, 2, 19));
    expect(event.end, DateTime(2026, 3, 6));
  });
}
