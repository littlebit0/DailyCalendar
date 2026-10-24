import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:pdf_document/pdf_document.dart';
import 'package:pdf_graphics/pdf_graphics.dart';
import 'academic_source.dart';

String _guideCalendar((Uint8List, int) input) {
  final (bytes, year) = input;
  final doc = PdfDocument.open(bytes);
  if (doc.pageCount > 250) {
    throw const FormatException('Unexpected Hoseo guide size');
  }
  for (var i = 0; i < doc.pageCount && i < 35; i++) {
    final text = PdfTextExtractor.extract(doc, i).text;
    if (text.replaceAll(RegExp(r'\s+'), '').contains('$year학년도주요학사일정안내') &&
        text.replaceAll(RegExp(r'\s+'), '').contains('동계계절학기')) {
      return text;
    }
  }
  throw const FormatException('Missing actual guide academic calendar');
}

class HoseoAcademicSource implements AcademicSource {
  HoseoAcademicSource({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  @override
  String get id => 'hoseo';
  @override
  String get name => '호서대학교';
  @override
  Uri get website => Uri.https('www.hoseo.ac.kr', '/Home/Contents.mbz', {
    'action': 'MAPP_2405312496',
  });
  static final _guide = Uri.https('www.hoseo.ac.kr', '/Home/Contents.mbz', {
    'action': 'MAPP_2302212208',
  });
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ko-KR,ko;q=0.9',
  };
  Future<Uint8List> _get(Uri url, {int limit = 8000000}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final response = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 || response.bodyBytes.length > limit) {
      throw const FormatException('Hoseo source unavailable');
    }
    return response.bodyBytes;
  }

  @override
  Future<List<AcademicEvent>> fetch(int year) async {
    final revisions = utf8.decode(
      await _get(
        Uri.https('www.hoseo.ac.kr', '/Search/Board.mbz', {
          'schKeyword': '학사일정 변경',
          'pageIndex': '1',
        }),
      ),
    );
    final revised = selectRevision(revisions, year);
    final events = revised == null
        ? parseAnnual(utf8.decode(await _get(website)), year)
        : await _revision(revised, year);
    events.addAll(await previousYearEvents(revisions, year));
    final unique = <String, AcademicEvent>{};
    for (final e in events) {
      if (e.start.isBefore(DateTime(year + 1)) &&
          e.end.isAfter(DateTime(year))) {
        unique[e.sourceId] = e;
      }
    }
    if (unique.isEmpty) throw const FormatException('Empty Hoseo calendar');
    return unique.values.toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<List<AcademicEvent>> _revision(Uri revised, int year) async {
    final bytes = await _get(revised);
    if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
      throw const FormatException('Expected Hoseo revised PDF');
    }
    final text = await Isolate.run(() {
      final doc = PdfDocument.open(bytes);
      if (doc.pageCount < 1 || doc.pageCount > 10) {
        throw const FormatException('Unexpected revised calendar size');
      }
      return List.generate(
        doc.pageCount,
        (i) => PdfTextExtractor.extract(doc, i).text,
      ).join('\n');
    }).timeout(const Duration(seconds: 30));
    return parseRevision(text, year, revised.toString());
  }

  /// Events of the previous academic year that continue into [year],
  /// such as the December-January winter session.
  Future<List<AcademicEvent>> previousYearEvents(
    String revisions,
    int year,
  ) async {
    Uri? revised;
    try {
      revised = selectRevision(revisions, year - 1);
    } on FormatException {
      // Image-only notices (e.g. 2025) carry no readable revised PDF; use the guide.
      revised = null;
    }
    final List<AcademicEvent> previous;
    if (revised != null) {
      previous = await _revision(revised, year - 1);
    } else {
      final guide = selectGuide(utf8.decode(await _get(_guide)), year - 1);
      final bytes = await _get(guide, limit: 60000000);
      if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
        throw const FormatException('Expected Hoseo official PDF');
      }
      final text = await Isolate.run(
        () => _guideCalendar((bytes, year - 1)),
      ).timeout(const Duration(seconds: 30));
      previous = parseGuide(text, year - 1, guide.toString());
    }
    return previous
        .where((e) => e.start.year < year && e.end.isAfter(DateTime(year)))
        .toList();
  }

  /// Select only actual published undergraduate revised calendar attachments.
  static Uri? selectRevision(String body, int year) {
    final doc = html.parse(body);
    if (doc.querySelector('#body article') == null) {
      throw const FormatException('Unexpected Hoseo revision search');
    }
    final candidates = <(DateTime, Uri)>[];
    for (final item in doc.querySelectorAll('#body article > ul > li')) {
      final directLinks = item.children.where(
        (e) => e.localName == 'a' && !e.classes.contains('info'),
      );
      final title = item.querySelector('h4 a') ?? directLinks.firstOrNull;
      if (title == null) continue;
      final label = _clean(title.text);
      if (!RegExp('^$year(?:-\\d)?학년도').hasMatch(label) ||
          !label.contains('학사일정') ||
          !label.contains('변경') ||
          label.contains('대학원')) {
        continue;
      }
      final article = Uri.tryParse(title.attributes['href'] ?? '');
      if (article == null ||
          !(article.host == 'hoseo.ac.kr' ||
              article.host.endsWith('.hoseo.ac.kr')) ||
          article.path != '/Home/BBSView.mbz') {
        throw const FormatException('Invalid Hoseo revision article');
      }
      final dateText = item.children
          .where((e) => e.localName == 'span')
          .map((e) => e.text.trim())
          .firstOrNull;
      if (dateText == null ||
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?$',
          ).hasMatch(dateText)) {
        throw const FormatException('Missing revision publication date');
      }
      final date = DateTime.parse(dateText);
      if (date
              .toIso8601String()
              .substring(0, dateText.length)
              .replaceFirst('T', ' ') !=
          dateText) {
        throw const FormatException('Invalid revision publication date');
      }
      var found = false;
      for (final file in item.querySelectorAll('ul a')) {
        final uri = Uri.tryParse(file.attributes['href'] ?? '');
        if (uri == null ||
            uri.path != '/File/Download.do' ||
            uri.queryParameters['dir'] != 'board') {
          continue;
        }
        final name = uri.queryParameters['realname'] ?? '';
        if (!name.contains('$year학년도 학사일정') ||
            !name.contains('수정본') ||
            !name.endsWith('.pdf')) {
          continue;
        }
        found = true;
        final resolved = Uri.https(
          'www.hoseo.ac.kr',
          uri.path,
          uri.queryParameters,
        );
        if (!candidates.any((e) => e.$2 == resolved)) {
          candidates.add((date, resolved));
        }
      }
      if (!found) {
        throw const FormatException('Missing published revised calendar');
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    if (candidates.length > 1 && candidates[0].$1 == candidates[1].$1) {
      throw const FormatException('Ambiguous latest Hoseo revision');
    }
    return candidates.first.$2;
  }

  static List<AcademicEvent> parseRevision(String text, int year, String url) {
    if (!text.replaceAll(RegExp(r'\s+'), '').contains('$year학년도학사일정(안)')) {
      throw const FormatException('Wrong revised academic year');
    }
    final events = <AcademicEvent>[];
    final scopes = <(int, int)>[];
    var inTable = false, calendarYear = year, month = 0;
    String? pendingDate;
    var holidayHeading = false, holidayCount = 0;
    final numeric = r'\d{1,2}(?:[/.]\s*\d{1,2})?\.?\([월화수목금토일]\)';
    final prefix = RegExp(
      '^($numeric(?:\\s*,\\s*$numeric)?(?:\\s*~\\s*$numeric)?)(?:\\s+(.+))?\$',
    );
    final holiday = RegExp(
      r'([가-힣0-9\s]+?)\s+(\d{4})\.(\d{2})\.(\d{2})\.\([월화수목금토일]\)(?:\s*~\s*(\d{2})\.(\d{2})\.\([월화수목금토일]\))?',
    );
    for (final raw in text.split('\n')) {
      var line = _clean(raw);
      if (line.isEmpty) continue;
      if (line.replaceAll(' ', '') == '월일정학사일정') {
        inTable = true;
        continue;
      }
      if (line.startsWith('§')) {
        inTable = false;
        if (line.replaceAll(' ', '').contains('$year학년도휴업일')) {
          holidayHeading = true;
        }
      }
      if (!inTable) {
        for (final h in holiday.allMatches(line)) {
          holidayCount++;
          final y = int.parse(h[2]!);
          if (y != year) throw const FormatException('Wrong holiday year');
          final sm = int.parse(h[3]!);
          final em = h[5] == null ? sm : int.parse(h[5]!);
          events.add(
            _event(
              h[1]!,
              _date(y, sm, int.parse(h[4]!)),
              _date(y + (em < sm ? 1 : 0), em, int.parse(h[6] ?? h[4]!)),
              url,
            ),
          );
        }
        continue;
      }
      if (line.startsWith('*') || RegExp(r'^-\s*\d+\s*-$').hasMatch(line)) {
        continue;
      }
      if (pendingDate != null) {
        if (prefix.hasMatch(line)) {
          throw const FormatException('Missing wrapped event title');
        }
        events.addAll(_ranges(pendingDate, line, calendarYear, month, url));
        pendingDate = null;
        continue;
      }
      final heading = RegExp(r'^(?:(\d{4})\.\s*)?(\d{1,2})$').firstMatch(line);
      final inline = RegExp(
        r'^(\d{1,2})\s+(\d{1,2}\([월화수목금토일]\).*)$',
      ).firstMatch(line);
      if (heading != null || inline != null) {
        if (heading?[1] != null) calendarYear = int.parse(heading![1]!);
        month = int.parse(heading?[2] ?? inline![1]!);
        final index = scopes.length;
        if (month != index % 12 + 1 || calendarYear != year + index ~/ 12) {
          throw const FormatException('Invalid revised month scope');
        }
        scopes.add((calendarYear, month));
        if (heading != null) continue;
        line = inline![2]!;
      }
      final row = prefix.firstMatch(line);
      if (row == null || month == 0) {
        throw FormatException('Unrecognized revised calendar row: $line');
      }
      if (row[2] == null) {
        pendingDate = row[1];
      } else {
        events.addAll(_ranges(row[1]!, row[2]!, calendarYear, month, url));
      }
    }
    if (scopes.length != 15 ||
        pendingDate != null ||
        events.isEmpty ||
        !holidayHeading ||
        holidayCount == 0) {
      throw const FormatException('Incomplete revised academic calendar');
    }
    return events;
  }

  static Uri selectGuide(String body, int year) {
    // The published guide embeds its PDF directory and retains previous annual filenames.
    if (!body.contains('${year}_hoseocampusbook.pdf') ||
        !html
            .parse(body)
            .querySelectorAll('iframe')
            .any(
              (e) =>
                  Uri.tryParse(
                    e.attributes['src'] ?? '',
                  )?.queryParameters['file']?.startsWith('/upload/down/pdf/') ==
                  true,
            )) {
      throw const FormatException('Previous Hoseo guide is not published');
    }
    return Uri.https(
      'www.hoseo.ac.kr',
      '/upload/down/pdf/${year}_hoseocampusbook.pdf',
    );
  }

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();
  static DateTime _date(int y, int m, int d) {
    final value = DateTime(y, m, d);
    if (value.year != y || value.month != m || value.day != d) {
      throw const FormatException('Invalid Hoseo date');
    }
    return value;
  }

  static AcademicEvent _event(
    String title,
    DateTime start,
    DateTime last,
    String url,
  ) {
    title = _clean(title);
    if (title.isEmpty || last.isBefore(start)) {
      throw const FormatException('Invalid Hoseo event');
    }
    return AcademicEvent(
      sourceId: '${start.toIso8601String()}:${last.toIso8601String()}:$title',
      title: title,
      start: start,
      end: DateTime(last.year, last.month, last.day + 1),
      url: url,
    );
  }

  /// Rows the source itself marks as graduate-school only: a trailing
  /// `(대학원)`, a leading `[대학원]`/`(대학원)`, or a title starting with
  /// `대학원 `. Rows whose target also names `학부`, e.g. `(학부/대학원)`, stay.
  static bool isGraduateOnly(String title) {
    final text = title.trim();
    final targets = [
      RegExp(r'\(([^()]*)\)\s*$').firstMatch(text)?.group(1),
      RegExp(r'^[\[(]([^\])]*)[\])]').firstMatch(text)?.group(1),
      if (text.startsWith('대학원 ')) text,
    ];
    return targets.any(
      (t) => t != null && t.contains('대학원') && !t.contains('학부'),
    );
  }

  static List<AcademicEvent> _ranges(
    String raw,
    String title,
    int y,
    int month,
    String url,
  ) {
    if (isGraduateOnly(_clean(title))) return const [];
    raw = raw
        .replaceAll(RegExp(r'\([월화수목금토일]\)'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('/', '.');
    final result = <AcademicEvent>[];
    (int, int) date(String text, int contextMonth) {
      final match = RegExp(r'^(?:(\d{1,2})\.)?(\d{1,2})\.?$').firstMatch(text);
      if (match == null) {
        throw const FormatException('Invalid Hoseo numeric period');
      }
      return (
        match[1] == null ? contextMonth : int.parse(match[1]!),
        int.parse(match[2]!),
      );
    }

    for (final part in raw.split(',')) {
      final ends = part.split('~');
      if (ends.isEmpty || ends.length > 2) {
        throw const FormatException('Invalid Hoseo range');
      }
      final (sm, sd) = date(ends.first, month);
      final (em, ed) = date(ends.last, sm);
      result.add(
        _event(
          title,
          _date(y, sm, sd),
          _date(y + (em < sm ? 1 : 0), em, ed),
          url,
        ),
      );
    }
    return result;
  }

  static List<AcademicEvent> parseAnnual(String body, int year) {
    final doc = html.parse(body);
    if (!doc
        .querySelectorAll('h3')
        .any((e) => _clean(e.text) == '$year학년도 학사일정')) {
      throw const FormatException('Wrong Hoseo annual year');
    }
    final months = doc.querySelectorAll('#academic_scd01 > ul > li');
    if (months.length != 15) {
      throw const FormatException('Incomplete Hoseo months');
    }
    final result = <AcademicEvent>[];
    for (final (i, section) in months.indexed) {
      final m = RegExp(
        r'^(?:(\d{4})\.)?(\d{1,2})월$',
      ).firstMatch(section.querySelector('.box-month')?.text.trim() ?? '');
      if (m == null ||
          int.parse(m[2]!) != i % 12 + 1 ||
          (m[1] == null ? year : int.parse(m[1]!)) != year + i ~/ 12) {
        throw const FormatException('Invalid Hoseo month scope');
      }
      for (final row in section.querySelectorAll('.list-box')) {
        result.addAll(
          _ranges(
            row.querySelector('.list-date')?.text ?? '',
            row.querySelector('.list-content')?.text ?? '',
            year + i ~/ 12,
            i % 12 + 1,
            'https://www.hoseo.ac.kr/Home/Contents.mbz?action=MAPP_2405312496',
          ),
        );
      }
    }
    return result;
  }

  static List<AcademicEvent> parseGuide(String body, int year, String url) {
    if (!body.replaceAll(RegExp(r'\s+'), '').contains('$year학년도주요학사일정안내')) {
      throw const FormatException('Wrong Hoseo guide year');
    }
    var currentYear = year, month = 0;
    final result = <AcademicEvent>[];
    for (final raw in body.split('\n')) {
      var line = raw.replaceAll(RegExp(r'\([월화수목금토일]\)'), '').trim();
      final heading = RegExp(
        r'^(?:(\d{4})\.\s*)?(\d{1,2})(?:\s+|$)',
      ).firstMatch(line);
      if (heading != null &&
          (line == heading[2] ||
              heading[1] != null ||
              RegExp(
                r'^\d{1,2}(?=\s|[~,])',
              ).hasMatch(line.substring(heading.end)))) {
        if (heading[1] != null) currentYear = int.parse(heading[1]!);
        month = int.parse(heading[2]!);
        line = line.substring(heading.end).trim();
        if (month < 1 ||
            month > 12 ||
            currentYear < year ||
            currentYear > year + 1) {
          throw const FormatException('Invalid Hoseo guide month');
        }
        if (line.isEmpty) continue;
      }
      if (month == 0 || !RegExp(r'^\d{1,2}').hasMatch(line)) continue;
      final pair = RegExp(
        r'^((?:\d{1,2}(?:\.\s*\d{1,2})?\.?)(?:\s*[~,]\s*(?:\d{1,2}(?:\.\s*\d{1,2})?\.?))*)\s+(.+)$',
      ).firstMatch(line);
      if (pair == null) {
        throw const FormatException('Incomplete Hoseo guide date/title');
      }
      result.addAll(_ranges(pair[1]!, pair[2]!, currentYear, month, url));
    }
    if (result.isEmpty) {
      throw const FormatException('Empty Hoseo guide calendar');
    }
    return result;
  }

  @override
  void close() => _client.close();
}
