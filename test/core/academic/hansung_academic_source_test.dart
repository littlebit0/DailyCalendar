import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/academic_source.dart';
import 'package:daily/core/academic/hansung_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(int year, {bool december = false}) => File(
  'test/fixtures/academic/hansung-$year${december ? '-12' : ''}.html',
).readAsStringSync();

List<AcademicEvent> parseYear(int year) => HansungAcademicSource.parse(
  fixture(year),
  year,
  decemberBody: fixture(year, december: true),
);

void main() {
  test('Hansung validates annual months and absolute overlap dates', () async {
    final requested = <String>[];
    final source = HansungAcademicSource(
      client: MockClient((request) async {
        expect(
          request.url.path,
          anyOf(
            '/schdulMng/hansung/39/yearSchdul.do',
            '/schdulMng/hansung/39/monthSchdul.do',
          ),
        );
        final body = Uri.splitQueryString(request.body);
        final december = request.url.path.contains('monthSchdul');
        if (december) expect(body['month'], '12');
        requested.add('${body['year']}${december ? '-12' : ''}');
        return http.Response(
          fixture(int.parse(body['year']!), december: december),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(requested, ['2025', '2025-12', '2026', '2026-12']);
    expect(
      events.where(
        (e) => e.title.contains('조기졸업 신청') && e.start == DateTime(2026, 9, 28),
      ),
      hasLength(1),
    );
    expect(
      events.singleWhere((e) => e.title == '종무식').start,
      DateTime(2026, 12, 31),
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
    expect(
      events.singleWhere((e) => e.title == '겨울계절학기 종강').start,
      DateTime(2026, 1, 13),
    );
    // Every 2026 event plus only previous-page rows that reach into 2026.
    final previous = parseYear(
      2025,
    ).where((e) => e.end.isAfter(DateTime(2026)));
    expect(events, hasLength(parseYear(2026).length + previous.length));
    expect(
      events.every(
        (e) =>
            e.start.isBefore(DateTime(2027)) && e.end.isAfter(DateTime(2026)),
      ),
      isTrue,
    );
  });

  test('every published Hansung row is imported for each year', () {
    for (final year in [2025, 2026]) {
      final rows = html
          .parse(fixture(year))
          .querySelectorAll('.box-sch .desc dl');
      // A period crossing months is listed under each month with one record.
      final records = {
        for (final row in rows)
          RegExp(
            r"set_layer\('(\d+)'",
          ).firstMatch(row.querySelector('dd a')!.attributes['onclick']!)![1],
      };
      expect(records.length, {2025: 71, 2026: 73}[year]);
      expect(parseYear(year), hasLength(records.length));
    }
  });

  test('Hansung December rows use the official month dates', () {
    // The annual page prints the next year on the last December row.
    for (final year in [2025, 2026]) {
      expect(
        parseYear(year).singleWhere((e) => e.title == '종무식').start,
        DateTime(year, 12, 31),
      );
    }
  });

  test('Hansung profile resolves to its registered calendar', () {
    for (final id in [
      'institution:academyinfo:0000200',
      'academyinfo:0000200',
    ]) {
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한성대학교',
          schoolKind: 'fourYear',
        ).academicSourceId,
        'hansung',
      );
    }
  });

  test('Hansung rejects year and bad dates', () {
    expect(
      () => HansungAcademicSource.parse(fixture(2026), 2025),
      throwsFormatException,
    );
    expect(
      () => HansungAcademicSource.parse(
        fixture(2026).replaceFirst('2026.01.02', '2026.02.30'),
        2026,
      ),
      throwsFormatException,
    );
    expect(
      () => HansungAcademicSource.parse(
        fixture(2026),
        2026,
        decemberBody: fixture(2025, december: true),
      ),
      throwsFormatException,
    );
  });

  test('Hansung failed response keeps the error visible', () async {
    final source = HansungAcademicSource(
      client: MockClient((request) async => http.Response('', 503)),
    );
    await expectLater(source.fetch(2026), throwsFormatException);
    source.close();
  });
}
