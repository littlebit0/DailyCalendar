import 'dart:io';
import 'package:daily/core/academic/kmou_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = File('test/fixtures/academic/kmou-2026.html').readAsStringSync();
  final pages = ['kmou-2025.txt', 'kmou-2025-page2.txt']
      .map((name) => File('test/fixtures/academic/$name').readAsStringSync())
      .toList();
  test('official PDF revised dates and complete previous winter survive', () {
    final events = KmouAcademicSource.parsePdfText(
      pages,
      2025,
      'https://www.kmou.ac.kr/',
    );
    expect(events, hasLength(63));
    final orientation = events.singleWhere(
      (e) => e.title.replaceAll(RegExp(r'\s+'), '') == '신입생오리엔테이션(해사대학)',
    );
    expect(orientation.start, DateTime(2026, 3, 2));
    expect(orientation.end, DateTime(2026, 3, 8));
    final winter = events.singleWhere((e) => e.title == '겨울계절학기 수업');
    expect(winter.start, DateTime(2025, 12, 26));
    expect(winter.end, DateTime(2026, 1, 17));
    expect(
      () => KmouAcademicSource.parsePdfText(
        pages,
        2024,
        'https://www.kmou.ac.kr/',
      ),
      throwsFormatException,
    );
  });
  test(
    'current HTML retains actual next winter and rejects wrong academic year',
    () {
      final events = KmouAcademicSource.parseHtml(body, 2026);
      expect(events, hasLength(63));
      final winter = events.singleWhere((e) => e.title == '겨울계절학기 수업');
      expect(winter.start, DateTime(2026, 12, 24));
      expect(winter.end, DateTime(2027, 1, 15));
      expect(
        () => KmouAcademicSource.parseHtml(body, 2025),
        throwsFormatException,
      );
      expect(
        () => KmouAcademicSource.selectPdf(body, 2030),
        throwsFormatException,
      );
    },
  );
  test(
    'actual PDF bytes extracted off main isolate and merged with current HTML',
    () async {
      final source = KmouAcademicSource(
        client: MockClient((request) async {
          expect(request.headers['User-Agent'], 'Mozilla/5.0');
          if (request.url.path.endsWith('nttFileDownload.do')) {
            expect(
              request.headers['Referer'],
              'https://www.kmou.ac.kr/onestop/cm/cntnts/cntntsView.do?mi=74&cntntsId=1755',
            );
            expect(
              request.url.queryParameters['fileKey'],
              '3a8af5d3a6c558c985cf6746f93a35c6',
            );
            return http.Response.bytes(
              File('test/fixtures/academic/kmou-2025.pdf').readAsBytesSync(),
              200,
            );
          }
          expect(
            request.headers['Referer'],
            'https://www.kmou.ac.kr/onestop/main.do',
          );
          return http.Response(
            body,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      try {
        final events = await source.fetch(2026);
        expect(events.map((e) => e.sourceId).toSet().length, events.length);
        expect(
          events
              .singleWhere(
                (e) => e.title == '겨울계절학기 수업' && e.start.year == 2025,
              )
              .end,
          DateTime(2026, 1, 17),
        );
        expect(
          events
              .singleWhere(
                (e) => e.title == '제2학기 성적열람' && e.start.year == 2025,
              )
              .end,
          DateTime(2026, 1, 5),
        );
      } finally {
        source.close();
      }
    },
  );
}
