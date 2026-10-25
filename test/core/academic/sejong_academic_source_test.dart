import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/sejong_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/sejong-$year.json').readAsStringSync();

void main() {
  test(
    'Sejong requests the undergraduate year and keeps cross-year grading',
    () async {
      final source = SejongAcademicSource(
        client: MockClient((r) async {
          expect(r.url.path, '/kor/academics/academic-calendar.do');
          expect(r.url.queryParameters, {
            'mode': 'getCalendarData',
            'collDiv': '0001',
            'start': '2026-01-01',
            'end': '2027-01-01',
          });
          return http.Response.bytes(
            utf8.encode(fixture(2026)),
            200,
            headers: {'content-type': 'application/json; charset=UTF-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(events, hasLength(44));
      final opening = events.singleWhere((e) => e.title == '2학기 개강');
      expect(opening.start, DateTime(2026, 9, 1));
      expect(opening.end, DateTime(2026, 9, 2));
      final grading = events.singleWhere(
        (e) => e.title == '2학기 기말고사 성적 열람 및 정정',
      );
      expect(grading.start, DateTime(2026, 12, 29));
      expect(grading.end, DateTime(2027, 1, 3));
      expect(events.map((e) => e.sourceId).toSet(), hasLength(44));
    },
  );

  test('every published Sejong row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = (jsonDecode(fixture(year))['data'] as List).length;
      expect(SejongAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });

  test('Sejong keeps the previous title and occurrence based IDs', () {
    final events = SejongAcademicSource.parse(fixture(2026), 2026);
    final opening = events.singleWhere((e) => e.title == '2학기 개강');
    final hash = sha256.convert(utf8.encode('2학기 개강')).toString();
    expect(opening.sourceId, '2026:$hash:0');
    final withdrawals = events.where((e) => e.title == '수강신청과목 철회');
    expect(withdrawals.map((e) => e.sourceId.split(':').last), ['0', '1']);
  });

  test('Sejong profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000138',
      'academyinfo:0000138',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '세종대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'sejong',
      );
    }
  });

  test('Sejong skips graduate rows and rejects malformed data', () {
    final json = jsonDecode(fixture(2026)) as Map<String, dynamic>;
    final first = (json['data'] as List).first as Map;
    (json['data'] as List).add({
      ...first,
      'collDiv': '0002',
      'scmSubject': 'Graduate only',
    });
    expect(SejongAcademicSource.parse(jsonEncode(json), 2026), hasLength(44));
    first['frDt'] = '2026-02-30';
    expect(
      () => SejongAcademicSource.parse(jsonEncode(json), 2026),
      throwsFormatException,
    );
    expect(
      () => SejongAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
    expect(() => SejongAcademicSource.parse('{}', 2026), throwsFormatException);
  });

  test('Sejong treats an unavailable response as an error', () async {
    final source = SejongAcademicSource(
      client: MockClient((_) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
