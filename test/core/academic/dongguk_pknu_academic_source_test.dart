import 'dart:io';
import 'package:daily/core/academic/dongguk_academic_source.dart';
import 'package:daily/core/academic/pknu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final (wise, count) in [(false, 90), (true, 88)]) {
    test(
      'Dongguk ${wise ? 'WISE' : 'Seoul'} keeps its own official undergraduate periods',
      () async {
        final source = DonggukAcademicSource(
          wise: wise,
          client: MockClient((request) async {
            expect(
              request.url.host,
              wise ? 'wise.dongguk.ac.kr' : 'www.dongguk.edu',
            );
            final year = request.url.queryParameters['schedule_start_date'];
            return http.Response(
              File(
                'test/fixtures/academic/dongguk-${wise ? 'wise' : 'seoul'}-$year.html',
              ).readAsStringSync(),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );
        addTearDown(source.close);
        final events = await source.fetch(2026);
        expect(events.length, count);
        expect(events.map((e) => e.sourceId).toSet().length, count);
        expect(events.any((e) => e.title.contains('대학원')), isFalse);
        expect(events.any((e) => e.title.contains('학·석사연계과정')), isTrue);
        final winter = events.singleWhere(
          (e) => e.title == '겨울 계절학기' && e.start == DateTime(2026, 12, 22),
        );
        expect(winter.start, DateTime(2026, 12, 22));
        expect(winter.end, DateTime(2027, 1, 14));
      },
    );
    test(
      'Dongguk ${wise ? 'WISE' : 'Seoul'} rejects stale row years and invalid dates',
      () {
        final body = File(
          'test/fixtures/academic/dongguk-${wise ? 'wise' : 'seoul'}-2026.html',
        ).readAsStringSync();
        expect(
          () => DonggukAcademicSource.parse(body, 2025, wise: wise),
          throwsFormatException,
        );
        expect(
          () => DonggukAcademicSource.parse(
            body.replaceFirst('2026.03.01.', '2026.03.32.'),
            2026,
            wise: wise,
          ),
          throwsFormatException,
        );
      },
    );
  }
  test(
    'PKNU invalid published winter end year cannot silently become a schedule',
    () {
      final body = File(
        'test/fixtures/academic/pknu-2026-12.json',
      ).readAsStringSync();
      expect(
        () => PknuAcademicSource.parse(body, 2026, 12),
        throwsFormatException,
      );
    },
  );
}
