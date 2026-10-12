import 'dart:io';

import 'package:daily/core/academic/ajou_academic_source.dart';
import 'package:daily/core/academic/gist_academic_source.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/skku_academic_source.dart';
import 'package:daily/core/academic/knu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  String fixture(String name) =>
      File('test/fixtures/academic/$name').readAsStringSync();
  final ajou = fixture('ajou-2026.html');
  final gist = fixture('gist-2026.html');
  test(
    'Ajou imports undergraduate events and preserves cross-year periods',
    () {
      final events = AjouAcademicSource.parse(ajou, 2026);
      expect(
        events.any(
          (e) =>
              e.start == DateTime(2026, 12, 30) &&
              e.end == DateTime(2027, 1, 5),
        ),
        isTrue,
      );
      expect(events.any((e) => e.title.contains('[학부]')), isFalse);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(() => AjouAcademicSource.parse(ajou, 2025), throwsFormatException);
      expect(
        () =>
            AjouAcademicSource.parse(ajou.replaceFirst('3(화)', '32(화)'), 2026),
        throwsFormatException,
      );
    },
  );
  test('Ajou serial fetch includes January from prior academic year', () async {
    final requested = <int>[];
    final source = AjouAcademicSource(
      client: MockClient((request) async {
        final year = int.parse(request.url.queryParameters['year']!);
        requested.add(year);
        return http.Response(
          fixture('ajou-$year.html'),
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    addTearDown(source.close);
    final events = await source.fetch(2026);
    expect(requested, [2025, 2026]);
    expect(events.length, 75);
    expect(events.any((e) => e.start.month == 1), isTrue);
    expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
  });
  test('GIST infers December of previous year in January section', () {
    final events = GistAcademicSource.parse(gist, 2026);
    expect(events.length, 94);
    final winter = events.singleWhere(
      (e) => e.title == '겨울학기 수강신청 변경' && e.start.year == 2025,
    );
    expect(winter.start, DateTime(2025, 12, 29));
    expect(winter.end, DateTime(2026, 1, 3));
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(() => GistAcademicSource.parse(gist, 2025), throwsFormatException);
    expect(
      () => GistAcademicSource.parse(
        gist.replaceFirst('<strong>01월</strong>', '<strong>13월</strong>'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => GistAcademicSource.parse(
        gist.replaceFirst('12-29(월)', '12-32(월)'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test(
    'GIST fetch requests full annual page using official form fields',
    () async {
      final source = GistAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(Uri.splitQueryString(request.body)['year'], '2026');
          expect(Uri.splitQueryString(request.body)['month'], '');
          return http.Response(
            gist,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      expect((await source.fetch(2026)).length, 94);
    },
  );
  test('Sookmyung flattens annual months and deduplicates repeated ranges', () {
    final body = fixture('sookmyung-2026.json');
    final events = SookmyungAcademicSource.parse(body, 2026);
    expect(events.length, greaterThan(100));
    expect(
      events.every(
        (e) => e.end.isAfter(e.start) && e.start.isBefore(DateTime(2027)),
      ),
      isTrue,
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(
      () => SookmyungAcademicSource.parse(
        body.replaceFirst('"hasData": true', '"hasData": false'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => SookmyungAcademicSource.parse('{"data":[]}', 2026),
      throwsFormatException,
    );
  });
  test('SKKU validates embedded record counts and next-year ranges', () {
    final body = fixture('skku-2026.html');
    final events = SkkuAcademicSource.parse(body, 2026);
    expect(events.length, 91);
    expect(events.any((e) => e.start.year == 2027), isTrue);
    expect(() => SkkuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => SkkuAcademicSource.parse(
        body.replaceFirst('2026-03-01', '2026-02-30'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test(
    'SKKU prefers current academic year for overlapping March entries',
    () async {
      final requests = <int>[];
      final source = SkkuAcademicSource(
        client: MockClient((request) async {
          final year = int.parse(
            request.url.queryParameters['srBachelorYear']!,
          );
          requests.add(year);
          return http.Response(
            fixture('skku-$year.html'),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      final events = await source.fetch(2026);
      expect(requests, [2025, 2026]);
      expect(events.length, 90);
      expect(events.where((e) => e.title == '1학기 개강').length, 1);
    },
  );
  test(
    'CUK preserves official campus names and stable calendar record IDs',
    () {
      final body = fixture('catholic-2026.json');
      final events = CatholicAcademicSource.parse(body, 2026);
      expect(events.length, 64);
      expect(events.any((e) => e.title.contains('성심교정·성의교정·성신교정')), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(
        () => CatholicAcademicSource.parse(body.replaceFirst('성심', '서울'), 2026),
        throwsFormatException,
      );
    },
  );
  test('KNU uses title periods rather than truncating to its date column', () {
    final body = fixture('knu-2026.html');
    final events = KnuAcademicSource.parse(body, 2026);
    expect(events.length, 62);
    expect(events.any((e) => e.title.startsWith('[대학원]')), isFalse);
    final spring = events.singleWhere((e) => e.title == '1학기 수강신청');
    expect(spring.start, DateTime(2026, 2, 10));
    expect(spring.end, DateTime(2026, 2, 13));
    expect(() => KnuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => KnuAcademicSource.parse(
        body.replaceFirst('02.10(화)', '02.30(화)'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
