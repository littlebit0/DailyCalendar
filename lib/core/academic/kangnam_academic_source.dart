import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';

import 'academic_source.dart';

/// The annual calendar in Kangnam's publicly published registration guide.
class KangnamAcademicSource implements AcademicSource {
  KangnamAcademicSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  @override
  String get id => 'kangnam';
  @override
  String get name => '강남대학교';
  @override
  Uri get website => guideUrl(DateTime.now().year);

  static Uri guideUrl(int year) => Uri.https(
    'app.kangnam.ac.kr',
    '/knumis/sb/sbm1050Download.jsp',
    {'gubn_code': '1', 'schl_smst': '2', 'schl_year': '$year'},
  );

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final events = <String, AcademicEvent>{};
    // Academic-year books include January and February of the following year.
    for (final selected in [year - 1, year]) {
      if (selected == year) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final response = await _client
          .get(guideUrl(selected))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || response.bodyBytes.length > 12000000) {
        throw const FormatException('Kangnam calendar unavailable');
      }
      final bytes = response.bodyBytes;
      final parsed = await Isolate.run(
        () => parsePdf(bytes, selected),
      ).timeout(const Duration(seconds: 30));
      for (final event in parsed) {
        if (event.start.isBefore(DateTime(year + 1)) &&
            event.end.isAfter(DateTime(year))) {
          events[event.sourceId] = event;
        }
      }
    }
    if (events.isEmpty) {
      throw const FormatException('No published Kangnam calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AcademicEvent> parsePdf(Uint8List bytes, int academicYear) {
    if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
      throw const FormatException('Expected Kangnam calendar PDF');
    }
    final document = PdfDocument.open(bytes);
    if (document.pageCount < 2 || document.pageCount > 250) {
      throw const FormatException('Unexpected Kangnam calendar document');
    }
    final events = <String, AcademicEvent>{};
    var calendarPages = 0;
    for (
      var pageIndex = 0;
      pageIndex < document.pageCount && pageIndex < 8;
      pageIndex++
    ) {
      final page = PdfTextExtractor.extract(document, pageIndex);
      final compact = page.text.replaceAll(RegExp(r'\s+'), '');
      if (!compact.contains('학사일정') ||
          !compact.contains('$academicYear') ||
          !compact.contains('일정내')) {
        continue;
      }
      calendarPages++;
      // Use the actual date/content columns, rather than the PDF text stream
      // which lists whole date columns before whole content columns.
      final runs = page.runs.where((r) => r.bounds.left >= 270).toList()
        ..sort((a, b) => b.bounds.bottom.compareTo(a.bounds.bottom));
      final lines = <List<PdfExtractedRun>>[];
      for (final run in runs) {
        if (lines.isEmpty ||
            (lines.last.first.bounds.bottom - run.bounds.bottom).abs() > 1) {
          lines.add([]);
        }
        lines.last.add(run);
      }
      for (final line in lines) {
        line.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        final nativeDate = line
            .where((r) => r.bounds.left < 375)
            .map((r) => r.text)
            .join()
            .replaceAll(RegExp(r'\s+'), '');
        final dates = RegExp(
          r'(\d{2})\.(\d{2})',
        ).allMatches(nativeDate).toList();
        if (dates.isEmpty) continue;
        if (dates.length > 2) {
          throw const FormatException('Ambiguous Kangnam calendar dates');
        }
        final title = line
            .where((r) => r.bounds.left >= 375)
            .map((r) => r.text)
            .join()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (title.isEmpty) {
          throw const FormatException('Missing Kangnam calendar title');
        }
        DateTime date(RegExpMatch match) {
          final month = int.parse(match[1]!);
          final day = int.parse(match[2]!);
          final year = academicYear + (month < 3 ? 1 : 0);
          final value = DateTime(year, month, day);
          if (value.month != month || value.day != day) {
            throw const FormatException('Invalid Kangnam calendar date');
          }
          return value;
        }

        final start = date(dates.first);
        final endMonth = int.parse(dates.last[1]!);
        final endDay = int.parse(dates.last[2]!);
        // A February-to-March application window remains in the same
        // following calendar year; only a decreasing month crosses New Year.
        final last = DateTime(
          start.year + (endMonth < start.month ? 1 : 0),
          endMonth,
          endDay,
        );
        if (last.month != endMonth || last.day != endDay) {
          throw const FormatException('Invalid Kangnam calendar end date');
        }
        if (last.isBefore(start)) {
          throw FormatException(
            'Reversed Kangnam calendar range: $nativeDate / $title',
          );
        }
        final identity = sha256.convert(utf8.encode('$start/$last/$title'));
        final event = AcademicEvent(
          sourceId: '$identity',
          title: title,
          start: start,
          end: DateTime(last.year, last.month, last.day + 1),
          url: guideUrl(academicYear).toString(),
        );
        events[event.sourceId] = event;
      }
    }
    if (calendarPages != 2 || events.length < 50) {
      throw const FormatException('Incomplete Kangnam annual calendar');
    }
    return events.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  void close() => _client.close();
}
