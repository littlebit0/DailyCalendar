import 'dart:io';
import 'package:daily/core/academic/hoseo_academic_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final body = File(
    'test/fixtures/academic/hoseo-2026.html',
  ).readAsStringSync();
  final guidePage = File(
    'test/fixtures/academic/hoseo-guide-page.html',
  ).readAsStringSync();
  final guideText = File(
    'test/fixtures/academic/hoseo-2025-guide.txt',
  ).readAsStringSync();
  test(
    'latest annual dates, discrete February dates and cross-month periods',
    () {
      final events = HoseoAcademicSource.parseAnnual(body, 2026);
      expect(events, hasLength(56));
      expect(
        events.singleWhere((e) => e.title == '2026학년도 2학기 개강').start,
        DateTime(2026, 8, 31),
      );
      final registration = events
          .where((e) => e.title == '1학기 수강신청 기간' && e.start.year == 2026)
          .toList();
      expect(registration, hasLength(2));
      expect(registration[0].start, DateTime(2026, 2, 6));
      expect(registration[0].end, DateTime(2026, 2, 7));
      expect(registration[1].start, DateTime(2026, 2, 9));
      expect(registration[1].end, DateTime(2026, 2, 13));
      final summer = events.singleWhere((e) => e.title == '하계계절학기');
      expect(summer.start, DateTime(2026, 6, 23));
      expect(summer.end, DateTime(2026, 7, 14));
      final winter = events.singleWhere((e) => e.title == '동계계절학기');
      expect(winter.end, DateTime(2027, 1, 13));
      expect(
        () => HoseoAcademicSource.parseAnnual(body, 2025),
        throwsFormatException,
      );
    },
  );
  test(
    'previous guide dates do not replace latest January and February dates',
    () {
      final events = HoseoAcademicSource.parseGuide(
        guideText,
        2025,
        'https://www.hoseo.ac.kr/',
      );
      final winter = events.singleWhere((e) => e.title == '동계계절학기');
      expect(winter.start, DateTime(2025, 12, 24));
      expect(winter.end, DateTime(2026, 1, 16));
      expect(
        events.singleWhere((e) => e.title == '2025학년도 1학기 개강').start,
        DateTime(2025, 3, 4),
      );
      expect(
        () => HoseoAcademicSource.selectGuide(guidePage, 2030),
        throwsFormatException,
      );
      expect(
        () => HoseoAcademicSource.parseGuide(
          guideText,
          2024,
          'https://www.hoseo.ac.kr/',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'real PDF extraction, published previous filename and filtered merge',
    () async {
      final source = HoseoAcademicSource(
        client: MockClient((request) async {
          expect(request.headers['Accept-Language'], contains('ko'));
          if (request.url.path == '/Search/Board.mbz') {
            return http.Response(
              '<div id="body"><article><ul></ul></article></div>',
              200,
            );
          }
          if (request.url.path.endsWith('.pdf')) {
            expect(
              request.url.path,
              '/upload/down/pdf/2025_hoseocampusbook.pdf',
            );
            return http.Response.bytes(
              File(
                'test/fixtures/academic/hoseo-2025-calendar.pdf',
              ).readAsBytesSync(),
              200,
            );
          }
          return http.Response(
            request.url.queryParameters['action'] == 'MAPP_2405312496'
                ? body
                : guidePage,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      try {
        final events = await source.fetch(2026);
        expect(events, hasLength(47));
        expect(
          events.singleWhere((e) => e.title.startsWith('제42회 학위수여식')).start,
          DateTime(2026, 2, 24),
        );
        expect(events.where((e) => e.start.year < 2026), hasLength(1));
        expect(events.map((e) => e.sourceId).toSet(), hasLength(47));
      } finally {
        source.close();
      }
    },
  );
  final revisions = File(
    'test/fixtures/academic/hoseo-revisions.html',
  ).readAsStringSync();
  final revisedText = File(
    'test/fixtures/academic/hoseo-2026-revised.txt',
  ).readAsStringSync();
  test(
    'latest published revision overrides stale annual dates and reads holiday footnotes',
    () {
      final uri = HoseoAcademicSource.selectRevision(revisions, 2026)!;
      expect(uri.queryParameters['savename'], '20260813085612_479009150575');
      final events = HoseoAcademicSource.parseRevision(
        revisedText,
        2026,
        uri.toString(),
      );
      expect(events, hasLength(62));
      expect(
        events.singleWhere((e) => e.title == '수시면접일').start,
        DateTime(2026, 10, 23),
      );
      final registration = events.singleWhere(
        (e) => e.title == '1학기 수강신청 기간' && e.start.year == 2027,
      );
      expect(registration.start, DateTime(2027, 2, 11));
      expect(registration.end, DateTime(2027, 2, 18));
      expect(
        events
            .singleWhere(
              (e) => e.title == '편입생/재입학생 수강신청 기간' && e.start.year == 2027,
            )
            .start,
        DateTime(2027, 2, 23),
      );
      expect(
        events.singleWhere((e) => e.title == '2027학년도 1학기 개강').start,
        DateTime(2027, 3, 2),
      );
      expect(
        () => HoseoAcademicSource.parseRevision(
          revisedText.replaceFirst('\n10\n', '\n'),
          2026,
          '',
        ),
        throwsFormatException,
      );
      expect(
        () => HoseoAcademicSource.parseRevision(revisedText, 2025, ''),
        throwsFormatException,
      );
      expect(
        () =>
            HoseoAcademicSource.selectRevision('<html>unexpected</html>', 2026),
        throwsFormatException,
      );
      expect(
        () => HoseoAcademicSource.selectRevision(
          revisions.replaceAll('2026-07-22 15:11:18', '2026-08-13 08:56:12'),
          2026,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'fetch extracts current real PDF before merging previous winter without requesting stale annual page',
    () async {
      final requested = <Uri>[];
      final source = HoseoAcademicSource(
        client: MockClient((r) async {
          requested.add(r.url);
          if (r.url.path == '/Search/Board.mbz') {
            return http.Response(
              revisions,
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
          if (r.url.path == '/File/Download.do') {
            return http.Response.bytes(
              File(
                'test/fixtures/academic/hoseo-2026-revised.pdf',
              ).readAsBytesSync(),
              200,
            );
          }
          if (r.url.path.endsWith('.pdf')) {
            return http.Response.bytes(
              File(
                'test/fixtures/academic/hoseo-2025-calendar.pdf',
              ).readAsBytesSync(),
              200,
            );
          }
          return http.Response(
            guidePage,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
      );
      try {
        final events = await source.fetch(2026);
        expect(events, hasLength(53));
        expect(
          events.singleWhere((e) => e.title == '수시면접일').start,
          DateTime(2026, 10, 23),
        );
        expect(events.where((e) => e.start.year < 2026), hasLength(1));
        expect(
          requested.where(
            (u) => u.queryParameters['action'] == 'MAPP_2405312496',
          ),
          isEmpty,
        );
      } finally {
        source.close();
      }
    },
  );
}
