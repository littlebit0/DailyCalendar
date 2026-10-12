import 'dart:io';
import 'package:daily/core/academic/sungshin_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, int month) => File(
  'test/fixtures/academic/sungshin-$year-${month.toString().padLeft(2, '0')}.html',
).readAsStringSync();
void main() {
  test('Sungshin year view needs every month and preceding winter', () async {
    final calls = <String>[];
    final source = SungshinAcademicSource(
      client: MockClient((request) async {
        final query = Uri.splitQueryString(request.body);
        calls.add('${query['year']}-${query['month']}');
        expect(request.url.path, '/schdulmanage/main_kor/25/yearSchdul.do');
        expect(query['kind'], 'N');
        return http.Response(
          fixture(int.parse(query['year']!), int.parse(query['month']!)),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(calls, ['2025-12', for (var m = 1; m <= 12; m++) '2026-$m']);
    expect(events, hasLength(39));
    expect(
      events.any(
        (e) =>
            e.title.contains('2025학년도 겨울계절수업') &&
            e.start == DateTime(2025, 12, 23) &&
            e.end == DateTime(2026, 1, 15),
      ),
      isTrue,
    );
    expect(
      events.any(
        (e) =>
            e.title.contains('2026학년도 겨울계절수업') &&
            e.start == DateTime(2026, 12, 23) &&
            e.end == DateTime(2027, 1, 15),
      ),
      isTrue,
    );
    expect(
      events.where((e) => e.title.contains('2026학년도 1학기 강의기간')),
      hasLength(1),
    );
  });
  test('Sungshin rejects wrong month, year and invalid dates', () {
    expect(
      () => SungshinAcademicSource.parse(fixture(2026, 3), 2026, 4),
      throwsFormatException,
    );
    expect(
      () => SungshinAcademicSource.parse(fixture(2026, 3), 2025, 3),
      throwsFormatException,
    );
    expect(
      () => SungshinAcademicSource.parse(
        fixture(2026, 3).replaceFirst('03-03', '02-30'),
        2026,
        3,
      ),
      throwsFormatException,
    );
    expect(SungshinAcademicSource.parse(fixture(2026, 1), 2026, 1), isEmpty);
  });
}
