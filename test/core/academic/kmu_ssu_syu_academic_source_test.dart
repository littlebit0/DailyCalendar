import 'dart:io';

import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/kmu_academic_source.dart';
import 'package:daily/core/academic/ssu_academic_source.dart';
import 'package:daily/core/academic/syu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final (school, query, count, factory)
      in <(String, String, int, AcademicSource Function(http.Client))>[
        (
          'kmu',
          'parm_doc_year',
          58,
          (client) => KmuAcademicSource(client: client),
        ),
        ('ssu', 'years', 61, (client) => SsuAcademicSource(client: client)),
        ('syu', 'c', 80, (client) => SyuAcademicSource(client: client)),
      ]) {
    test(
      '$school reads complete official annual fixtures without duplicate views',
      () async {
        final requests = <String>[];
        final source = factory(
          MockClient((request) async {
            final year = request.url.queryParameters[query]!;
            requests.add(year);
            return http.Response(
              File(
                'test/fixtures/academic/$school-$year.html',
              ).readAsStringSync(),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );
        addTearDown(source.close);
        final events = await source.fetch(2026);
        expect(requests, ['2025', '2026']);
        expect(events.length, count);
        expect(events.map((e) => e.sourceId).toSet().length, count);
        expect(
          events.every(
            (e) =>
                e.end.isAfter(e.start) &&
                e.start.isBefore(DateTime(2027)) &&
                e.end.isAfter(DateTime(2026)),
          ),
          isTrue,
        );
        expect(events.any((e) => e.title.contains('개강')), isTrue);
        expect(events.any((e) => e.start.month == 1), isTrue);
        expect(events.any((e) => e.start.month == 12), isTrue);
      },
    );
  }

  test('SSU refuses a stale year and invalid date', () {
    final body = File(
      'test/fixtures/academic/ssu-2026.html',
    ).readAsStringSync();
    expect(() => SsuAcademicSource.parse(body, 2025), throwsFormatException);
    expect(
      () => SsuAcademicSource.parse(
        body.replaceFirst('01.05 (월)', '01.32 (월)'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('KMU and SYU refuse stale academic years', () {
    expect(
      () => KmuAcademicSource.parse(
        File('test/fixtures/academic/kmu-2026.html').readAsStringSync(),
        2025,
      ),
      throwsFormatException,
    );
    expect(
      () => SyuAcademicSource.parse(
        File('test/fixtures/academic/syu-2026.html').readAsStringSync(),
        2025,
      ),
      throwsFormatException,
    );
  });
}
