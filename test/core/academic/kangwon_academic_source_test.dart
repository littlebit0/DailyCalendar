import 'dart:io';

import 'package:daily/core/academic/kangwon_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Kangwon imports official integrated campus calendars with shared IDs',
    () async {
      final months = <int>[];
      final source = KangwonAcademicSource(
        client: MockClient((request) async {
          final month = int.parse(request.url.queryParameters['searchMonth']!);
          months.add(month);
          return http.Response(
            File(
              'test/fixtures/academic/kangwon-2026-${month.toString().padLeft(2, '0')}.json',
            ).readAsStringSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(source.close);
      expect(source.website.host, 'www.kangwon.ac.kr');
      final events = await source.fetch(2026);
      expect(months, List.generate(12, (i) => i + 1));
      expect(events.length, 81);
      expect(events.any((e) => e.title.endsWith('(춘천)')), isTrue);
      expect(events.any((e) => e.title.endsWith('(삼척)')), isTrue);
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.url.contains('kangwon.ac.kr')), isTrue);
    },
  );
  test('Kangwon refuses a stale month response and invalid date', () {
    final body = File(
      'test/fixtures/academic/kangwon-2026-03.json',
    ).readAsStringSync();
    expect(
      () => KangwonAcademicSource.parse(body, 2025, 3),
      throwsFormatException,
    );
    expect(
      () => KangwonAcademicSource.parse(
        body.replaceFirst('2026.03.03', '2026.03.32'),
        2026,
        3,
      ),
      throwsFormatException,
    );
  });
}
