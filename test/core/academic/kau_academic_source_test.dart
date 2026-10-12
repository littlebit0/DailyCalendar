import 'dart:io';
import 'package:daily/core/academic/kau_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture() =>
    File('test/fixtures/academic/kau-2026.html').readAsStringSync();
void main() {
  test('KAU uses updated website dates and abbreviated range ends', () async {
    final source = KauAcademicSource(
      client: MockClient((request) async {
        expect(request.url.path, '/kaulife/schedule.php');
        return http.Response(
          fixture(),
          200,
          headers: {'content-type': 'text/html;charset=utf-8'},
        );
      }),
    );
    final events = await source.fetch(2026);
    source.close();
    expect(events, hasLength(45));
    expect(
      events.singleWhere((e) => e.title == '하계 계절학기 종강').start,
      DateTime(2026, 7, 20),
    );
    expect(
      events.singleWhere((e) => e.title == '1학기 보강').end,
      DateTime(2026, 6, 24),
    );
    expect(
      events.singleWhere((e) => e.title == '동계 계절학기 종강').start,
      DateTime(2026, 1, 13),
    );
    expect(events.map((e) => e.sourceId).toSet().length, events.length);
  });
  test('KAU rejects unpublished year and invalid dates', () {
    expect(
      () => KauAcademicSource.parse(fixture(), 2025),
      throwsFormatException,
    );
    expect(
      () => KauAcademicSource.parse(
        fixture().replaceFirst('2026. 1. 1', '2026. 2. 30'),
        2026,
      ),
      throwsFormatException,
    );
  });
}
