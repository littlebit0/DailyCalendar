import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/bu_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year) =>
    File('test/fixtures/academic/bu-$year.json').readAsStringSync();
void main() {
  test(
    'BU queries both academic years and preserves preceding winter',
    () async {
      final years = <String>[];
      final source = BuAcademicSource(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/totalSchdul/web/jsonYearSchdul.do');
          final year = request.bodyFields['year']!;
          years.add(year);
          return http.Response(
            fixture(int.parse(year)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final events = await source.fetch(2026);
      source.close();
      expect(years, ['2025', '2026']);
      expect(events, hasLength(90));
      expect(events.map((e) => e.sourceId).toSet().length, events.length);
      final winter = events.singleWhere(
        (e) => e.title == '동계 계절학기' && e.start.year == 2025,
      );
      expect(winter.start, DateTime(2025, 12, 22));
      expect(winter.end, DateTime(2026, 1, 14));
      expect(events.every((e) => e.start.isBefore(DateTime(2027))), isTrue);
    },
  );
  test('every published BU row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = (jsonDecode(fixture(year)) as Map).length;
      expect(BuAcademicSource.parse(fixture(year), year), hasLength(rows));
    }
  });
  test('BU profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000178',
      'academyinfo:0000178',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '백석대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'bu',
      );
    }
  });
  test('BU rejects invalid dates and unexpected year', () {
    expect(
      () => BuAcademicSource.parse(fixture(2026), 2028),
      throwsFormatException,
    );
    expect(
      () => BuAcademicSource.parse(
        fixture(2026).replaceFirst('2026.01.02', '2026.02.30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(() => BuAcademicSource.parse('{}', 2026), throwsFormatException);
  });
}
