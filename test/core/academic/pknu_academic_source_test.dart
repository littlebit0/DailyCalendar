import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/pknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) =>
    File('test/fixtures/academic/pknu-$name').readAsStringSync();
String month(int year, int month) =>
    fixture('$year-${month.toString().padLeft(2, '0')}.json');

PknuAcademicSource source(List<String> requested, {int status = 200}) =>
    PknuAcademicSource(
      client: MockClient((r) async {
        if (r.url.host == 'stat.pknu.ac.kr') {
          expect(r.url.path, '/stat/281');
          requested.add('stat');
          return http.Response(
            fixture('stat-2026.html'),
            status,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }
        expect(r.url.path, '/getScheduleList.do');
        final q = Uri.splitQueryString(r.body);
        expect(q['steId'], 'IEav5ISH');
        requested.add('${q['year']}-${q['month']}');
        return http.Response(
          month(int.parse(q['year']!), int.parse(q['month']!)),
          status,
          headers: {'content-type': 'application/json;charset=utf-8'},
        );
      }),
    );

void main() {
  test(
    'PKNU 2026 keeps cross-year rows and verifies the reversed winter row',
    () async {
      final requested = <String>[];
      final pknu = source(requested);
      addTearDown(pknu.close);
      final events = await pknu.fetch(2026);
      expect(requested, [
        '2025-12',
        '2026-01',
        'stat',
        for (var m = 2; m <= 12; m++) '2026-${m.toString().padLeft(2, '0')}',
      ]);
      expect(events, hasLength(56));
      expect(events.any((e) => e.title.contains('학위청구')), isFalse);
      final winter = events.singleWhere((e) => e.sourceId == '2091');
      expect(winter.title, '동계 계절수업');
      expect(winter.start, DateTime(2026, 12, 21));
      expect(winter.end, DateTime(2027, 1, 13));
      expect(winter.url, 'https://stat.pknu.ac.kr/stat/281');
      final previous = events.singleWhere((e) => e.sourceId == '1452');
      expect(previous.start, DateTime(2025, 12, 22));
      expect(previous.end, DateTime(2026, 1, 14));
      expect(previous.url, 'https://www.pknu.ac.kr/main/31');
    },
  );
  test(
    'every published PKNU row is imported except graduate-only rows',
    () async {
      for (final (year, graduate) in [(2025, 10), (2026, 10)]) {
        final rows = <String, String>{
          for (var m = 1; m <= 12; m++)
            for (final row in jsonDecode(month(year, m))['list'] as List)
              '${row['schSeq']}': row['schNm'] as String,
        };
        final excluded = {
          for (final e in rows.entries)
            if (PknuAcademicSource.isGraduateOnly(e.value)) e.key,
        };
        // Thesis and language/comprehensive exam rows each semester.
        expect(excluded, hasLength(graduate));
        expect(
          rows.entries
              .where((e) => excluded.contains(e.key))
              .every((e) => RegExp(r'대학원 (학위청구|외국어)').hasMatch(e.value)),
          isTrue,
        );
        final pknu = source([]);
        final events = await pknu.fetch(year);
        pknu.close();
        expect(events, hasLength(rows.length - graduate));
        expect(
          events.map((e) => e.sourceId).toSet(),
          rows.keys.toSet().difference(excluded),
        );
      }
    },
  );
  test('PKNU keeps rows shared with graduate students', () {
    for (final title in [
      '제2학기 현금등록 (대학원, 전문대학원 및 특수대학원 포함)',
      '제1학기 수강취소 (일반대학원생, 경영대학원생, 교육대학원생 제외)',
      '2026년 2월 학위수여식',
    ]) {
      expect(PknuAcademicSource.isGraduateOnly(title), isFalse);
    }
    expect(PknuAcademicSource.isGraduateOnly('제1학기 대학원 외국어 및 종합시험 실시'), isTrue);
  });
  test('PKNU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000013',
      'academyinfo:0000013',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '국립부경대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'pknu',
      );
    }
  });
  test(
    'PKNU invalid published winter end year cannot silently become a schedule',
    () {
      expect(
        () => PknuAcademicSource.parse(month(2026, 12), 2026, 12),
        throwsFormatException,
      );
    },
  );
  test('PKNU rejects malformed dates, empty years and failed responses', () {
    expect(
      () => PknuAcademicSource.parse(
        month(2026, 3).replaceFirst('"20260303"', '"20260332"'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    expect(
      () => PknuAcademicSource.parse(month(2026, 3), 2026, 5),
      throwsFormatException,
    );
    final empty = PknuAcademicSource(
      client: MockClient((_) async => http.Response('{"list":[]}', 200)),
    );
    addTearDown(empty.close);
    expect(empty.fetch(2026), throwsFormatException);
    final failed = source([], status: 500);
    addTearDown(failed.close);
    expect(failed.fetch(2026), throwsFormatException);
  });
}
