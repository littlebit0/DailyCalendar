import 'dart:io';
import 'package:daily/core/academic/suwon_academic_source.dart';
import 'package:daily/core/academic/hansung_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String school, int year, String extension) =>
    File('test/fixtures/academic/$school-$year.$extension').readAsStringSync();
void main() {
  test('Suwon keeps preceding winter and full official year', () async {
    final source = SuwonAcademicSource(
      client: MockClient((request) async {
        expect(request.url.path, '/mainHp/FrontSchdulManageMonthAjax.html');
        expect(Uri.splitQueryString(request.body)['year'], '2026');
        return http.Response(
          fixture('suwon', 2026, 'json'),
          200,
          headers: {'content-type': 'application/json;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(25));
    expect(events.first.start, DateTime(2025, 12, 22));
    expect(events.first.end, DateTime(2026, 1, 10));
    expect(events.last.end, DateTime(2027, 1, 16));
    expect(events.every((e) => e.end.isAfter(e.start)), isTrue);
  });
  test('Suwon rejects stale year and invalid dates', () {
    expect(
      () => SuwonAcademicSource.parse(fixture('suwon', 2026, 'json'), 2025),
      throwsFormatException,
    );
    expect(
      () => SuwonAcademicSource.parse(
        fixture(
          'suwon',
          2026,
          'json',
        ).replaceFirst('202602020000', '202602300000'),
        2026,
      ),
      throwsFormatException,
    );
  });
  test('Hansung validates annual months and absolute overlap dates', () async {
    final source = HansungAcademicSource(
      client: MockClient((request) async {
        expect(
          request.url.path,
          anyOf(
            '/schdulMng/hansung/39/yearSchdul.do',
            '/schdulMng/hansung/39/monthSchdul.do',
          ),
        );
        final year = int.parse(Uri.splitQueryString(request.body)['year']!);
        return http.Response(
          File(
            'test/fixtures/academic/hansung-$year${request.url.path.contains('monthSchdul') ? '-12' : ''}.html',
          ).readAsStringSync(),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
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
      DateTime(2026,1,13),
    );
  });
  test('Hansung rejects year and bad dates', () {
    expect(
      () => HansungAcademicSource.parse(fixture('hansung', 2026, 'html'), 2025),
      throwsFormatException,
    );
    expect(
      () => HansungAcademicSource.parse(
        fixture(
          'hansung',
          2026,
          'html',
        ).replaceFirst('2026.01.02', '2026.02.30'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
