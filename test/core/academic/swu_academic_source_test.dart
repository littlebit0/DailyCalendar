import 'dart:io';
import 'package:daily/core/academic/swu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int month) => File(
  'test/fixtures/academic/swu-2026-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();
void main() {
  test(
    'SWU gets full periods from all monthly views rather than start-only annual',
    () async {
      final months = <int>[];
      final source = SwuAcademicSource(
        client: MockClient((request) async {
          expect(request.url.path, '/schdulMng/swu/15/monthSchdul.do');
          final data = Uri.splitQueryString(request.body);
          expect(data['year'], '2026');
          final month = int.parse(data['month']!);
          months.add(month);
          return http.Response(
            fixture(month),
            200,
            headers: {'content-type': 'text/html;charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(months, List.generate(12, (i) => i + 1));
      expect(
        events.where((e) => e.title == '중간고사(권장)').map((e) => (e.start, e.end)),
        [
          (DateTime(2026, 4, 21), DateTime(2026, 4, 28)),
          (DateTime(2026, 10, 20), DateTime(2026, 10, 27)),
        ],
      );
      expect(
        events.singleWhere((e) => e.title == '겨울계절학기 종료').start,
        DateTime(2026, 1, 13),
      );
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    },
  );
  test('SWU rejects wrong month/year and invalid dates', () {
    expect(
      () => SwuAcademicSource.parse(fixture(10), 2025, 10),
      throwsFormatException,
    );
    expect(
      () => SwuAcademicSource.parse(fixture(10), 2026, 11),
      throwsFormatException,
    );
    expect(
      () => SwuAcademicSource.parse(
        fixture(10).replaceFirst('10.03', '02.30'),
        2026,
        10,
      ),
      throwsFormatException,
    );
  });
}
