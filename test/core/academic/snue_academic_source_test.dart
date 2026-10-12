import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/snue_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/snue-$year.json').readAsStringSync();
void main() {
  test(
    'SNUE annual calendar preserves undergraduate scope and cross-month periods',
    () async {
      final years = <String>[];
      final source = SnueAcademicSource(
        client: MockClient((request) async {
          final form = Uri.splitQueryString(request.body);
          expect(request.method, 'POST');
          expect(request.url.path, '/snue/sm/schdul/selectSchdulInfo.do');
          expect(form['yearFirst'], 'Y');
          expect(form['schdulId'], '1000');
          expect(form['sysId'], 'snue');
          years.add(form['year']!);
          return http.Response(
            fixture(int.parse(form['year']!)),
            200,
            headers: {'content-type': 'application/json;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, ['2025', '2026']);
      expect(events, hasLength(65));
      expect(
        events.any(
          (e) =>
              e.title.startsWith('[학부] 2학기 교육실습 :') &&
              e.start == DateTime(2026, 10, 26) &&
              e.end == DateTime(2026, 11, 7),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) => e.title.contains('[학부/대학원]') && e.title.contains('개강'),
        ),
        isTrue,
      );
      expect(
        events.any(
          (e) =>
              e.title.startsWith('[대학원]') ||
              e.title.startsWith('[부설초]') ||
              e.title.startsWith('[평생교육원]'),
        ),
        isFalse,
      );
    },
  );
  test(
    'SNUE rejects incomplete annual data, bad dates and conflicting articles',
    () {
      final rows = jsonDecode(fixture(2026)) as List;
      expect(
        () => SnueAcademicSource.parse(fixture(2026), 2025),
        throwsFormatException,
      );
      expect(
        () => SnueAcademicSource.parse(
          jsonEncode(
            rows.where((r) => !r['bgnde'].startsWith('2026/07')).toList(),
          ),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SnueAcademicSource.parse(
          jsonEncode([
            ...rows,
            {...rows.first as Map, 'endde': '2026/02/30'},
          ]),
          2026,
        ),
        throwsFormatException,
      );
      expect(
        () => SnueAcademicSource.parse(
          jsonEncode([
            ...rows,
            {...rows.first as Map, 'schdulCn': 'Contradictory title'},
          ]),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
}
