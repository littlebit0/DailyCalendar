import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';
import 'academic_source.dart';

List<String> _pdfPages(Uint8List bytes) {
  final doc = PdfDocument.open(bytes);
  if (doc.pageCount < 1 || doc.pageCount > 8) {
    throw const FormatException('Unexpected academic PDF page count');
  }
  return [
    for (var i = 0; i < doc.pageCount; i++)
      PdfTextExtractor.extract(doc, i).text,
  ];
}

class KmouAcademicSource implements AcademicSource {
  KmouAcademicSource({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'kmou';
  @override
  String get name => '국립한국해양대학교';
  @override
  Uri get website => Uri.https(
    'www.kmou.ac.kr',
    '/onestop/cm/cntnts/cntntsView.do',
    {'mi': '74', 'cntntsId': '1755'},
  );

  Future<Uint8List> _get(Uri uri, {required Uri referer}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'text/html,application/pdf;q=0.9,*/*;q=0.8',
            'Referer': referer.toString(),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
      throw const FormatException('KMOU academic source unavailable');
    }
    return response.bodyBytes;
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final body = utf8.decode(
      await _get(
        website,
        referer: Uri.https('www.kmou.ac.kr', '/onestop/main.do'),
      ),
    );
    final doc = html.parse(body);
    final events = parseHtml(body, year);
    final previous = selectPdf(body, year - 1);
    final bytes = await _get(previous, referer: website);
    if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
      throw const FormatException('Expected official academic PDF');
    }
    final pages = await Isolate.run(
      () => _pdfPages(bytes),
    ).timeout(const Duration(seconds: 20));
    events.addAll(parsePdfText(pages, year - 1, previous.toString()));
    if (doc.querySelectorAll('table.table_st').length != 2) {
      throw const FormatException('Incomplete KMOU annual semesters');
    }
    final unique = <String, AcademicEvent>{};
    for (final e in events) {
      if (e.start.isBefore(DateTime(year + 1)) &&
          e.end.isAfter(DateTime(year))) {
        unique[e.sourceId] = e;
      }
    }
    if (unique.isEmpty) throw const FormatException('Empty KMOU calendar');
    return unique.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  static Uri selectPdf(String body, int year) {
    final candidates = html
        .parse(body)
        .querySelectorAll('a.btn_down')
        .where((e) => e.text.replaceAll(RegExp(r'\s+'), '') == '$year학년도학사일정표')
        .toList();
    if (candidates.length != 1) {
      throw const FormatException('Missing KMOU annual PDF');
    }
    final url = Uri.https(
      'www.kmou.ac.kr',
      '/',
    ).resolve(candidates.single.attributes['href'] ?? '');
    if (url.scheme != 'https' ||
        url.host != 'www.kmou.ac.kr' ||
        url.path != '/common/nttFileDownload.do' ||
        !RegExp(
          r'^[a-f0-9]{32}$',
        ).hasMatch(url.queryParameters['fileKey'] ?? '')) {
      throw const FormatException('Invalid KMOU published PDF link');
    }
    return url;
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
  static String _withoutWeekdays(String value) =>
      value.replaceAll(RegExp(r'\([월화수목금토일]\s*\)'), '');
  static final _datePattern = RegExp(
    r"^\s*(?:[’‘']?(\d{2})\.\s*)?(\d{1,2})\.\s*(\d{1,2})\.?\s*",
  );
  static (DateTime, String) _date(String raw, int contextYear) {
    final m = _datePattern.firstMatch(raw);
    if (m == null) throw const FormatException('Invalid KMOU numeric date');
    final y = m[1] == null ? contextYear : 2000 + int.parse(m[1]!);
    final month = int.parse(m[2]!), day = int.parse(m[3]!);
    final date = DateTime(y, month, day);
    if (date.year != y || date.month != month || date.day != day) {
      throw const FormatException('Invalid KMOU date');
    }
    return (date, raw.substring(m.end));
  }

  static (DateTime, DateTime, String) _period(String raw, int year) {
    final (start, tail) = _date(raw, year);
    if (!tail.startsWith('~')) return (start, start, tail.trim());
    final (last, rest) = _date(tail.substring(1), start.year);
    if (last.isBefore(start)) {
      throw const FormatException('Reversed KMOU period');
    }
    return (start, last, rest.trim());
  }

  static AcademicEvent _event(
    DateTime start,
    DateTime last,
    String title,
    String url,
  ) {
    title = _clean(title);
    if (title.isEmpty) throw const FormatException('Missing KMOU event title');
    return AcademicEvent(
      sourceId:
          '${start.toIso8601String()}:${last.toIso8601String()}:${title.replaceAll(RegExp(r'\s+'), '')}',
      title: title,
      start: start,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url,
    );
  }

  static List<AcademicEvent> parseHtml(String body, int year) {
    final tables = html.parse(body).querySelectorAll('table.table_st');
    if (tables.length != 2) {
      throw const FormatException('Incomplete KMOU semesters');
    }
    final result = <AcademicEvent>[];
    for (final table in tables) {
      var contextYear = year;
      for (final row in table.querySelectorAll('tbody > tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length != 2) {
          throw const FormatException('Invalid KMOU academic row');
        }
        final (start, last, tail) = _period(
          _withoutWeekdays(cells[0].text),
          contextYear,
        );
        if (tail.isNotEmpty ||
            (result.isEmpty && start.year != year) ||
            start.year < year ||
            start.year > year + 1) {
          throw const FormatException('Wrong KMOU annual year');
        }
        contextYear = start.year;
        result.add(
          _event(
            start,
            last,
            cells[1].text,
            'https://www.kmou.ac.kr/onestop/cm/cntnts/cntntsView.do?mi=74&cntntsId=1755',
          ),
        );
      }
    }
    return result;
  }

  static List<AcademicEvent> parsePdfText(
    List<String> pages,
    int year,
    String url,
  ) {
    final result = <AcademicEvent>[];
    for (final page in pages) {
      if (!page.replaceAll(RegExp(r'\s+'), '').contains('$year학년도학사일정')) {
        throw const FormatException('Wrong KMOU PDF academic year');
      }
      var contextYear = year;
      (DateTime, DateTime, String)? pending;
      void flush() {
        if (pending != null) {
          result.add(_event(pending!.$1, pending!.$2, pending!.$3, url));
        }
        pending = null;
      }

      for (final raw in page.split('\n')) {
        final line = _withoutWeekdays(raw).trim();
        if (!_datePattern.hasMatch(line)) {
          if (pending != null && line.isNotEmpty) {
            pending = (pending!.$1, pending!.$2, '${pending!.$3} $line');
          }
          continue;
        }
        flush();
        var (start, last, title) = _period(line, contextYear);
        // A revised date is printed in a separate 변경 column, after 당초.
        if (_datePattern.hasMatch(title)) {
          (start, last, title) = _period(title, start.year);
        }
        if (start.year < year || start.year > year + 1) {
          throw const FormatException('Invalid KMOU PDF scope');
        }
        // A wrapped title is accumulated until the next dated row.
        contextYear = start.year;
        pending = (start, last, title);
      }
      flush();
    }
    if (result.isEmpty) throw const FormatException('Empty KMOU annual PDF');
    return result;
  }

  @override
  void close() => _client.close();
}
