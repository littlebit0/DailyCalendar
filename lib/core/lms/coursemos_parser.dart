import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'lms_models.dart';

/// Safe codes only: neither HTML nor names/grades are included in errors.
class CoursemosParseException implements Exception {
  const CoursemosParseException(
    this.code, {
    this.authenticationRequired = false,
  });
  final String code;
  final bool authenticationRequired;
  @override
  String toString() => 'CoursemosParseException($code)';
}

class CoursemosCourse {
  const CoursemosCourse({
    required this.id,
    required this.title,
    required this.url,
  });
  final String id;
  final String title;
  final Uri url;
}

class CoursemosActivity {
  const CoursemosActivity({
    required this.id,
    required this.title,
    required this.course,
    required this.type,
    required this.url,
    this.dueAt,
    this.submissionStatus,
  });
  final String id;
  final String title;
  final CoursemosCourse course;
  final String type;
  final Uri url;
  final DateTime? dueAt;
  final String? submissionStatus;
}

class CoursemosActivityIndex {
  CoursemosActivityIndex({
    required Iterable<CoursemosActivity> activities,
    required this.rawRowCount,
    required this.ignoredHeadingCount,
    this.ignoredEmptyCount = 0,
  }) : activities = List.unmodifiable(activities);
  final List<CoursemosActivity> activities;
  final int rawRowCount;
  final int ignoredHeadingCount;
  final int ignoredEmptyCount;
}

/// Parses only read-only course listings and activity indexes. Activity detail
/// links are retained for an explicit user action and are never fetched here.
class CoursemosParser {
  const CoursemosParser();

  List<CoursemosCourse> courses(LmsHtmlPage page) {
    final document = _document(page);
    if (page.url.path != '/' && page.url.path != '/index.php') {
      throw const CoursemosParseException('unexpected_dashboard');
    }
    _checkPagination(document);
    final listing = document.querySelector('#region-main .course_lists');
    if (listing == null) {
      throw const CoursemosParseException('course_list_missing');
    }
    final courses = <String, CoursemosCourse>{};
    final referencedIds = <String>{};
    for (final anchor in listing.querySelectorAll('a.course_link[href]')) {
      final url = _resolve(page.url, anchor.attributes['href']!);
      if (url == null || url.path != '/course/view.php') {
        throw const CoursemosParseException('unrecognized_course_link');
      }
      if (url.origin != page.url.origin) {
        throw const CoursemosParseException('external_course');
      }
      final id = _numericId(url);
      referencedIds.add(id);
      final titleElement = anchor.querySelector('.course-title h3');
      final title = titleElement == null ? '' : _text(titleElement);
      if (title.isEmpty) {
        continue; // Course image and title may be separate links.
      }
      final previous = courses[id];
      if (previous != null && previous.title != title) {
        throw const CoursemosParseException('conflicting_course');
      }
      courses[id] = CoursemosCourse(id: id, title: title, url: url);
    }
    if (referencedIds.length != courses.length) {
      throw const CoursemosParseException('incomplete_course_titles');
    }
    // A changed dashboard must not look like a successfully empty enrollment.
    // Add an empty-dashboard marker only after verifying its official markup.
    if (courses.isEmpty) {
      throw const CoursemosParseException('unverified_empty_dashboard');
    }
    return List.unmodifiable(courses.values);
  }

  CoursemosActivityIndex activities(
    LmsHtmlPage page, {
    required CoursemosCourse course,
    required String type,
  }) {
    final document = _document(page);
    final module = switch (type) {
      'assignment' => 'assign',
      'quiz' => 'quiz',
      _ => throw const CoursemosParseException('unsupported_activity'),
    };
    if (page.url.origin != course.url.origin ||
        page.url.path != '/mod/$module/index.php' ||
        page.url.queryParameters['id'] != course.id) {
      throw const CoursemosParseException('unexpected_activity_index');
    }
    _checkPagination(document);
    final tables = document
        .querySelector('#region-main, [role="main"]')!
        .querySelectorAll('table.generaltable');
    if (tables.isEmpty) {
      final main = document.querySelector('#region-main, [role="main"]');
      final notice = main?.querySelector(
        type == 'quiz' ? '#notice.generalbox' : '.alert.alert-danger',
      );
      final heading = main?.querySelector('h2');
      final form = main?.querySelector('.continuebutton form[method="get"]');
      final returnUrl = form == null
          ? null
          : _resolve(page.url, form.attributes['action'] ?? '');
      if (notice != null &&
          _text(notice) ==
              (type == 'quiz' ? '이 강좌에는 퀴즈가 없습니다.' : '이 강좌에는 과제가 없습니다.') &&
          heading != null &&
          _text(heading) == (type == 'quiz' ? '퀴즈' : '과제') &&
          returnUrl?.origin == page.url.origin &&
          returnUrl?.path == '/course/view.php' &&
          form?.querySelector('input[name="id"]')?.attributes['value'] ==
              course.id) {
        return CoursemosActivityIndex(
          activities: const [],
          rawRowCount: 0,
          ignoredHeadingCount: 0,
        );
      }
    }
    if (tables.length != 1) {
      throw const CoursemosParseException('activity_table_missing');
    }
    final table = tables.single;
    final headers = table
        .querySelectorAll('thead th')
        .map((cell) => _text(cell).replaceAll(RegExp(r'\s+'), ''))
        .toList();
    final expected = type == 'assignment'
        ? const ['주', '과제', '종료일시', '제출', '성적']
        : const ['주', '제목', '종료일시', '성적'];
    if (headers.isNotEmpty && headers[0] == '주제') headers[0] = '주';
    if (headers.length != expected.length ||
        Iterable<int>.generate(
          expected.length,
        ).any((index) => headers[index] != expected[index])) {
      throw const CoursemosParseException('activity_headers_changed');
    }
    final bodies = table.children.where(
      (element) => element.localName == 'tbody',
    );
    if (bodies.length != 1) {
      throw const CoursemosParseException('activity_body_missing');
    }
    final rows = bodies.single.children
        .where((element) => element.localName == 'tr')
        .toList();
    if (bodies.single.classes.contains('empty') && rows.length == 1) {
      final cells = rows.single.children;
      if (cells.length == 1 &&
          cells.single.localName == 'td' &&
          int.tryParse(cells.single.attributes['colspan'] ?? '') ==
              headers.length &&
          cells.single.children.isEmpty &&
          _text(cells.single).isEmpty) {
        return CoursemosActivityIndex(
          activities: const [],
          rawRowCount: 1,
          ignoredHeadingCount: 0,
          ignoredEmptyCount: 1,
        );
      }
    }
    final spans = <int, _Span>{};
    final found = <String, CoursemosActivity>{};
    var ignored = 0;
    for (final row in rows) {
      final cells = _expandRow(row, headers.length, spans);
      final rawCells = row.children
          .where(
            (element) => element.localName == 'td' || element.localName == 'th',
          )
          .toList();
      if (rawCells.length == 1 &&
          int.tryParse(rawCells.single.attributes['colspan'] ?? '') ==
              headers.length &&
          rawCells.single.querySelector('a[href]') == null) {
        final text = _text(rawCells.single);
        final divider =
            text.isEmpty &&
            rawCells.single.querySelector('.tabledivider') != null;
        final weekHeading = RegExp(r'^\d+\s*주(?:차)?(?:\s|\[|$)').hasMatch(text);
        if (divider || weekHeading) {
          ignored++;
          continue;
        }
      }
      final links = cells[1]
          .querySelectorAll('a[href]')
          .map((anchor) {
            final url = _resolve(page.url, anchor.attributes['href']!);
            return (anchor: anchor, url: url);
          })
          .where((item) => item.url?.path == '/mod/$module/view.php')
          .toList();
      if (links.length != 1 || links.single.url!.origin != page.url.origin) {
        throw const CoursemosParseException('unrecognized_activity_row');
      }
      final link = links.single;
      final id = _numericId(link.url!);
      final title = _text(link.anchor);
      if (title.isEmpty || found.containsKey(id)) {
        throw const CoursemosParseException('invalid_activity_identity');
      }
      found[id] = CoursemosActivity(
        id: id,
        title: title,
        course: course,
        type: type,
        url: link.url!,
        dueAt: parseKoreanDate(_text(cells[2])),
        submissionStatus: type == 'assignment' ? _text(cells[3]) : null,
      );
    }
    if (spans.isNotEmpty) {
      throw const CoursemosParseException('incomplete_rowspan');
    }
    return CoursemosActivityIndex(
      activities: found.values,
      rawRowCount: rows.length,
      ignoredHeadingCount: ignored,
    );
  }

  /// The verified SMU indexes use Korean wall time. Never use the device's zone.
  static DateTime? parseKoreanDate(String source) {
    final value = source.trim();
    if (const {
      '',
      '-',
      '—',
      '없음',
      '기한 없음',
      '종료일 없음',
      '제한 없음',
    }.contains(value)) {
      return null;
    }
    final match = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(value);
    if (match == null) {
      throw const CoursemosParseException('unknown_deadline_format');
    }
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match[i] ?? '0')];
    final wall = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    if (wall.year != parts[0] ||
        wall.month != parts[1] ||
        wall.day != parts[2] ||
        wall.hour != parts[3] ||
        wall.minute != parts[4] ||
        wall.second != parts[5]) {
      throw const CoursemosParseException('invalid_deadline');
    }
    return wall.subtract(const Duration(hours: 9));
  }
}

Document _document(LmsHtmlPage page) {
  final document = html_parser.parse(page.html);
  if (page.url.path.contains('/login/') ||
      document.querySelector('input[type="password"]') != null) {
    throw const CoursemosParseException(
      'login_required',
      authenticationRequired: true,
    );
  }
  if (document.querySelector('#region-main, [role="main"]') == null) {
    throw const CoursemosParseException('page_structure_changed');
  }
  return document;
}

void _checkPagination(Document document) {
  if (document.querySelector('a[rel="next"], .pagination a, .paging a') !=
      null) {
    throw const CoursemosParseException('partial_paginated_listing');
  }
}

String _text(Element element) =>
    element.text.replaceAll(RegExp(r'\s+'), ' ').trim();

Uri? _resolve(Uri base, String href) {
  final resolved = base.resolve(href);
  return resolved.scheme == 'https' ? resolved : null;
}

String _numericId(Uri url) {
  final id = url.queryParameters['id'];
  if (id == null || !RegExp(r'^[1-9]\d*$').hasMatch(id)) {
    throw const CoursemosParseException('invalid_source_id');
  }
  return id;
}

class _Span {
  _Span(this.cell, this.remaining);
  final Element cell;
  int remaining;
}

List<Element> _expandRow(Element row, int width, Map<int, _Span> spans) {
  final result = List<Element?>.filled(width, null);
  for (final entry in spans.entries.toList()) {
    result[entry.key] = entry.value.cell;
    if (--entry.value.remaining == 0) spans.remove(entry.key);
  }
  var column = 0;
  for (final cell in row.children.where(
    (element) => element.localName == 'td' || element.localName == 'th',
  )) {
    while (column < width && result[column] != null) {
      column++;
    }
    final columns = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 0;
    final rows = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 0;
    if (columns < 1 || rows < 1 || rows > 10000 || column + columns > width) {
      throw const CoursemosParseException('invalid_table_span');
    }
    for (var offset = 0; offset < columns; offset++) {
      if (result[column] != null) {
        throw const CoursemosParseException('overlapping_table_span');
      }
      result[column] = cell;
      if (rows > 1) spans[column] = _Span(cell, rows - 1);
      column++;
    }
  }
  if (result.any((cell) => cell == null)) {
    throw const CoursemosParseException('incomplete_activity_row');
  }
  return result.cast<Element>();
}
