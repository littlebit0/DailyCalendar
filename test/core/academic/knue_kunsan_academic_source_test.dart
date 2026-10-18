import 'dart:io';
import 'package:daily/core/academic/knue_kunsan_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String source, int year) =>
    File('test/fixtures/academic/$source-$year.html').readAsStringSync();

void main() {
  for (final (sourceId, count) in [('knue', 52), ('kunsan', 75)]) {
    test(
      '$sourceId fetches official previous/current years and keeps winter overlaps',
      () async {
        final years = <int>[];
        final client = MockClient((request) async {
          final year = int.parse(
            request.url.queryParameters[sourceId == 'knue'
                ? 'searchY'
                : 'sYear']!,
          );
          years.add(year);
          return http.Response(
            fixture(sourceId, year),
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        });
        final source = sourceId == 'knue'
            ? KnueKunsanAcademicSource.knue(client: client)
            : KnueKunsanAcademicSource.kunsan(client: client);
        final events = await source.fetch(2026);
        source.close();
        expect(years, [2025, 2026]);
        expect(events, hasLength(count));
        expect(events.map((e) => e.sourceId).toSet(), hasLength(count));
        expect(
          events.any((e) => e.start.year == 2025 && e.end.year == 2026),
          isTrue,
        );
        expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
        if (sourceId == 'knue') {
          expect(events.any((e) => e.title.contains('대학·대학원')), isTrue);
          expect(events.any((e) => e.title.contains('대학원 외국어')), isFalse);
        }
      },
    );
  }
  test(
    'KNUE keeps the mixed semester-start row but not graduate-only rows',
    () {
      final events = KnueKunsanAcademicSource.parse(
        fixture('knue', 2025),
        2025,
        knue: true,
        requestedYear: 2025,
      );
      final start = events.singleWhere((e) => e.title == '제2학기 개강, 대학원 후기 입학일');
      expect(start.start, DateTime(2025, 9, 1));
      expect(start.end, DateTime(2025, 9, 2));
      expect(start.sourceId, contains('1021'));
      expect(events.any((e) => e.title.contains('대학원 외국어')), isFalse);
      expect(events.any((e) => e.title.contains('입학전형')), isFalse);
      expect(events.any((e) => e.title.contains('대학·대학원')), isTrue);
    },
  );
  test('Annual selection and twelve month coverage are required', () {
    final body = fixture('knue', 2026);
    expect(
      () => KnueKunsanAcademicSource.parse(body, 2025, knue: true),
      throwsFormatException,
    );
    expect(
      () => KnueKunsanAcademicSource.parse(
        body.replaceFirst('3월</th>', '4월</th>'),
        2026,
        knue: true,
      ),
      throwsFormatException,
    );
  });
  test(
    'Kunsan rejects source error when relevant, without inventing an end date',
    () {
      final previous = fixture('kunsan', 2025);
      expect(
        () => KnueKunsanAcademicSource.parse(previous, 2025, knue: false),
        throwsFormatException,
      );
      expect(
        () => KnueKunsanAcademicSource.parse(
          previous,
          2025,
          knue: false,
          requestedYear: 2026,
        ),
        returnsNormally,
      );
      final current = fixture(
        'kunsan',
        2026,
      ).replaceFirst('10/30(금)', '10/30(금) ~ 10/02(금)');
      expect(
        () => KnueKunsanAcademicSource.parse(
          current,
          2026,
          knue: false,
          requestedYear: 2026,
        ),
        throwsFormatException,
      );
    },
  );
  test('KNUE invalid day and unknown detail identity are refused', () {
    final body = fixture('knue', 2026);
    expect(
      () => KnueKunsanAcademicSource.parse(
        body.replaceFirst('>01</em>', '>32</em>'),
        2026,
        knue: true,
      ),
      throwsFormatException,
    );
    expect(
      () => KnueKunsanAcademicSource.parse(
        body.replaceFirst('key=542&schdleNum=', 'key=999&schdleNum='),
        2026,
        knue: true,
      ),
      throwsFormatException,
    );
  });
}
