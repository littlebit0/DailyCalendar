import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/ajou_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/ajou-$year.html').readAsStringSync();

void main() {
  test(
    'Ajou imports undergraduate events and preserves cross-year periods',
    () {
      final events = AjouAcademicSource.parse(fixture(2026), 2026);
      expect(
        events.any(
          (e) =>
              e.title == '2학기 성적 이의신청' &&
              e.start == DateTime(2026, 12, 30) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title == '신정' &&
              e.start == DateTime(2027, 1, 1) &&
              e.end == DateTime(2027, 1, 2),
        ),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('[학부]')), isFalse);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
    },
  );

  test('every published Ajou row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.b-cal-list-box .b-cal-wrap .b-cal-undergrad > li')
          .length;
      expect(rows, year == 2025 ? 67 : 77);
      expect(AjouAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });

  test('Ajou keeps title and occurrence based IDs', () {
    final events = AjouAcademicSource.parse(fixture(2026), 2026);
    final early = events.where((e) => e.title == '조기졸업 신청').toList();
    expect(early.map((e) => e.sourceId), ['2026:조기졸업 신청:0', '2026:조기졸업 신청:1']);
    expect(early.map((e) => e.start), [
      DateTime(2026, 3, 3),
      DateTime(2026, 9, 1),
    ]);
  });

  test('Ajou serial fetch includes January from prior academic year', () async {
    final requested = <int>[];
    final source = AjouAcademicSource(
      client: MockClient((request) async {
        expect(request.url.path, '/kr/bachelor/schedule.do');
        expect(request.url.queryParameters['mode'], 'userList');
        final year = int.parse(request.url.queryParameters['year']!);
        requested.add(year);
        return http.Response(
          fixture(year),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    addTearDown(source.close);
    final events = await source.fetch(2026);
    expect(requested, [2025, 2026]);
    expect(events.length, 75);
    expect(
      events.any(
        (e) =>
            e.title == '2학기 성적 이의신청' &&
            e.start == DateTime(2025, 12, 30) &&
            e.end == DateTime(2026, 1, 3),
      ),
      isTrue,
    );
    expect(events.any((e) => e.start.month == 1), isTrue);
    expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
    expect(events.every((e) => e.end.isAfter(DateTime(2026))), isTrue);
  });

  test('Ajou fetch fails on unavailable or empty responses', () async {
    for (final response in [
      http.Response('', 503),
      http.Response('<div class="b-cal-day-box"><span>2025</span></div>', 200),
    ]) {
      final source = AjouAcademicSource(
        client: MockClient((_) async => response),
      );
      addTearDown(source.close);
      await expectLater(source.fetch(2026), throwsFormatException);
    }
  });

  test('Ajou rejects incorrect year and malformed published date', () {
    final body = fixture(2026);
    expect(() => AjouAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => AjouAcademicSource.parse(body.replaceFirst('3(화)', '32(화)'), 2026),
      throwsFormatException,
    );
    expect(
      () => AjouAcademicSource.parse(body.replaceFirst('3월', '13월'), 2026),
      throwsFormatException,
    );
  });

  test('Ajou profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000146',
      'academyinfo:0000146',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '아주대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'ajou',
      );
    }
  });
}
