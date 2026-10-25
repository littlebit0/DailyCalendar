import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/smu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/smu-$year.json').readAsStringSync();

Map<String, Object?> row({
  String start = '2026-09-01',
  String end = '2026-09-07',
  String id = '766720',
}) => {
  'articleNo': int.parse(id),
  'boardNo': '85',
  'articleTitle': '수강신청 정정',
  'etcChar6': start,
  'etcChar7': end,
  'etcChar8': 'etc',
};
String response(List<Map<String, Object?>> rows) =>
    jsonEncode({'success': true, 'list': rows});

void main() {
  test('every published SMU row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = (jsonDecode(fixture(year))['list'] as List).length;
      expect(
        SangmyungAcademicSource.parse(fixture(year), year),
        hasLength(rows),
      );
    }
  });

  test('SMU fixture keeps cross-year rows, end dates and article URLs', () {
    final events = SangmyungAcademicSource.parse(fixture(2026), 2026);
    expect(events, hasLength(63));
    final winter = events.firstWhere((e) => e.sourceId == '751463');
    expect(winter.title, '2025-동계 계절수업');
    expect(winter.start, DateTime(2025, 12, 22));
    expect(winter.end, DateTime(2026, 1, 9));
    final last = events.firstWhere((e) => e.sourceId == '766730');
    expect(last.start, DateTime(2026, 12, 22));
    expect(last.end, DateTime(2027, 1, 9));
    expect(
      last.url,
      'https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=766730&boardNo=85',
    );
    expect(
      SangmyungAcademicSource.parse(
        fixture(2025),
        2025,
      ).firstWhere((e) => e.sourceId == '751433').title,
      '2025-1학기 중간강의평가',
    );
  });

  test(
    'official JSON includes end date and ignores unrelated boards; IDs survive edits',
    () {
      final parsed = SangmyungAcademicSource.parse(
        response([
          row(),
          {...row(id: '999'), 'boardNo': '86'},
          {...row(id: '998'), 'deleteYn': 'Y'},
          {...row(id: '997'), 'secretYn': 'Y'},
        ]),
        2026,
      );
      expect(parsed, hasLength(1));
      expect(parsed.single.end, DateTime(2026, 9, 8));
      final edited = AcademicEvent(
        sourceId: '766720',
        title: 'changed',
        start: DateTime(2026, 9, 3),
        end: DateTime(2026, 9, 8),
        url: parsed.single.url,
      );
      expect(parsed.single.dailyId('smu'), edited.dailyId('smu'));
      expect(
        parsed.single.dailyId('another'),
        isNot(parsed.single.dailyId('smu')),
      );
    },
  );

  test('JSON handles year crossing, one-day and leap-day bounds', () {
    final parsed = SangmyungAcademicSource.parse(
      response([
        row(id: '1', start: '2023-12-30', end: '2024-01-02'),
        row(id: '2', start: '2024-02-29', end: '2024-02-29'),
        row(id: '3', start: '2025-01-01', end: '2025-01-01'),
      ]),
      2024,
    );
    expect(parsed, hasLength(2));
    expect(parsed.last.end, DateTime(2024, 3, 1));
  });

  test(
    'malformed, impossible dates, incomplete, conflicting and empty data fail closed',
    () {
      for (final body in [
        '<html>maintenance</html>',
        '{}',
        response([]),
        response([row(start: '2026-02-30')]),
        response([row(start: '2026-09-09')]),
        response([
          {...row(), 'articleTitle': ''},
        ]),
        response([row(), row(end: '2026-09-09')]),
      ]) {
        expect(
          () => SangmyungAcademicSource.parse(body, 2026),
          throwsA(anything),
        );
      }
    },
  );

  test(
    'HTTP uses official undergraduate board and calendar year; status errors fail',
    () async {
      final api = SangmyungAcademicSource(
        client: MockClient((request) async {
          expect(request.url.host, 'www.smu.ac.kr');
          expect(request.url.path, '/app/common/selectDataList.do');
          final body = Uri.splitQueryString(request.body);
          expect(body['sqlId'], 'jw.Article.selectCalendarArticle');
          expect(jsonDecode(body['jsonStr']!)['bachelorBoardNoList'], ['85']);
          expect(jsonDecode(body['jsonStr']!)['year'], '2026');
          return http.Response(
            fixture(2026),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(await api.fetch(2026), hasLength(63));
      api.close();
      final failed = SangmyungAcademicSource(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(failed.fetch(2026), throwsFormatException);
      failed.close();
    },
  );

  test('SMU profiles on both campuses resolve to its registered calendar', () {
    for (final (universityId, campusId) in [
      ('institution:academyinfo:0000117', null),
      ('institution:academyinfo:0000117', 'academyinfo:0000117'),
      ('institution:academyinfo:0000117', 'academyinfo:0002959'),
      ('academyinfo:0000117', null),
      ('academyinfo:0002959', null),
    ]) {
      expect(
        AcademicProfile(
          universityId: universityId,
          universityName: '상명대학교',
          schoolKind: 'fourYear',
          campusId: campusId,
        ).academicSourceId,
        'smu',
      );
    }
  });
}
