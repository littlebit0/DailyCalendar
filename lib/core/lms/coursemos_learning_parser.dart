part of 'coursemos_parser.dart';

/// A user-progress row. The source ID is the report's opaque module identity;
/// it must not be used as a Moodle course-module URL ID.
class CoursemosLearningRow {
  const CoursemosLearningRow({
    required this.title,
    this.module,
    this.moduleId,
    this.rawOpenAt,
    this.rawDueAt,
    this.requiredLearningSeconds,
    this.learnedSeconds,
    this.progressPercent,
    this.courseModuleId,
  });

  final String title;
  final String? module;
  final String? moduleId;
  final String? rawOpenAt;
  final String? rawDueAt;
  final int? requiredLearningSeconds;
  final int? learnedSeconds;
  final double? progressPercent;
  final String? courseModuleId;

  /// This is an opaque report identity, not a Moodle course-module link ID.
  String? get sourceIdentity => module != null && courseModuleId != null
      ? 'cm:$module:$courseModuleId'
      : module != null && moduleId != null
      ? '$module:$moduleId'
      : null;

  String? get activityType => switch (module) {
    'vod' || 'econtents' => 'lecture',
    _ => null,
  };

  DateTime? get openAt => CoursemosLearningParser.parsePeriod(rawOpenAt);
  DateTime? get dueAt => CoursemosLearningParser.parsePeriod(rawDueAt);

  bool get hasValidPeriod {
    final start = openAt;
    final end = dueAt;
    return start != null && end != null && end.isAfter(start);
  }

  bool get hasRequiredFields =>
      title.isNotEmpty &&
      sourceIdentity != null &&
      activityType != null &&
      hasValidPeriod &&
      requiredLearningSeconds != null &&
      requiredLearningSeconds! > 0 &&
      (learnedSeconds != null && learnedSeconds! >= 0 ||
          courseModuleId != null && learnedSeconds == null);
}

class CoursemosLearningIndex {
  CoursemosLearningIndex({
    required Iterable<CoursemosLearningRow> rows,
    required this.rawRowCount,
    required this.ignoredEmptyCount,
    required this.course,
    required this.reportUrl,
    this.trackingUnavailable = false,
  }) : rows = List.unmodifiable(rows);

  final List<CoursemosLearningRow> rows;
  final int rawRowCount;
  final int ignoredEmptyCount;
  final CoursemosCourse course;
  final Uri reportUrl;
  final bool trackingUnavailable;

  /// Known zero requirements are reference/nonattendance material, not missing
  /// source data. They produce no deadline even without identity or period data.
  int get excludedNonAttendanceCount =>
      rows.where((row) => row.requiredLearningSeconds == 0).length;
  int get unresolvedRowCount => rows
      .where(
        (row) => row.requiredLearningSeconds != 0 && !row.hasRequiredFields,
      )
      .length;

  /// Only describes extraction of this table. It does not establish that the
  /// server returned every enrolled course or that an absent activity is deleted.
  bool get coverageComplete =>
      trackingUnavailable || rows.isNotEmpty && unresolvedRowCount == 0;

  /// Confirmed rows only. Callers must retain [coverageComplete] and may not
  /// infer deletion from missing rows or present this subset as full coverage.
  List<CoursemosActivity> get activities => List.unmodifiable([
    for (final row in rows)
      if (row.hasRequiredFields)
        CoursemosActivity(
          id: 'report:${row.sourceIdentity}',
          title: row.title,
          course: course,
          type: row.activityType!,
          // The report's modid has not been verified as a course-module ID.
          url: row.courseModuleId == null
              ? reportUrl
              : course.url.replace(fragment: 'module-${row.courseModuleId}'),
          openAt: row.openAt,
          dueAt: row.dueAt,
          requiredLearningSeconds: row.requiredLearningSeconds,
          learnedSeconds: row.learnedSeconds,
          sourceCompleted: row.learnedSeconds == null
              ? null
              : row.learnedSeconds! >= row.requiredLearningSeconds!,
          progressPercent: row.progressPercent,
        ),
  ]);
}

/// Reads only the verified SMU user-progress table. It never follows activity
/// links or report detail controls, whose handlers can issue POST requests.
class CoursemosLearningParser {
  const CoursemosLearningParser();

  CoursemosLearningIndex parse(
    LmsHtmlPage page, {
    required CoursemosCourse course,
  }) {
    final document = _document(page);
    if (page.url.origin != course.url.origin ||
        page.url.path != '/report/ubcompletion/user_progress.php' ||
        page.url.queryParametersAll.length != 1 ||
        page.url.queryParametersAll['id']?.length != 1 ||
        page.url.queryParameters['id'] != course.id ||
        page.url.fragment.isNotEmpty ||
        page.url.userInfo.isNotEmpty) {
      throw const CoursemosParseException('unexpected_learning_report');
    }
    _checkPagination(document);
    final tables = document.querySelectorAll(
      '#ubcompletion-progress-wrapper table.user_progress',
    );
    if (tables.isEmpty &&
        document.querySelectorAll('#ubcompletion-progress-wrapper').length ==
            1 &&
        document
            .querySelectorAll('#ubcompletion-progress-wrapper .alert-danger')
            .any(
              (notice) =>
                  _text(notice) ==
                  '등록된 학습자원/활동이 존재하지 않거나, 진도관리가 활성화된 학습자원/활동이 없습니다.',
            )) {
      return CoursemosLearningIndex(
        rows: const [],
        rawRowCount: 0,
        ignoredEmptyCount: 0,
        course: course,
        reportUrl: page.url,
        trackingUnavailable: true,
      );
    }
    if (tables.length != 1) {
      throw const CoursemosParseException('learning_table_missing');
    }
    final table = tables.single;
    final headers = table
        .querySelectorAll('thead th')
        .map((cell) => _text(cell).replaceAll(RegExp(r'\s+'), ''))
        .toList();
    if (headers.isNotEmpty && headers.first == '주제') {
      headers[0] = '주';
    }
    const expected = ['주', '강의자료', '출석인정요구시간', '총학습시간', '진도율'];
    if (headers.length != expected.length ||
        Iterable<int>.generate(
          expected.length,
        ).any((index) => headers[index] != expected[index])) {
      throw const CoursemosParseException('learning_headers_changed');
    }
    final bodies = table.children.where(
      (element) => element.localName == 'tbody',
    );
    if (bodies.length != 1) {
      throw const CoursemosParseException('learning_body_missing');
    }
    final sourceRows = bodies.single.children.where(
      (element) => element.localName == 'tr',
    );
    final rows = <CoursemosLearningRow>[];
    final identities = <String>{};
    final spans = <int, _Span>{};
    var ignoredEmpty = 0;
    for (final sourceRow in sourceRows) {
      final cells = _expandRow(sourceRow, expected.length, spans);
      // The current report explicitly renders unused weeks as a numeric week
      // cell followed by four empty cells. Unstudied named rows are not empty.
      final week = _text(cells[0]);
      if ((week.isEmpty || RegExp(r'^\d+$').hasMatch(week)) &&
          cells.skip(1).every((cell) => _text(cell).isEmpty) &&
          sourceRow.querySelector('[data-modname], [data-modid], a[href]') ==
              null) {
        ignoredEmpty++;
        continue;
      }
      final markers = sourceRow.querySelectorAll('[data-modname][data-modid]');
      String? module;
      String? moduleId;
      String? start;
      String? end;
      if (markers.length == 1) {
        final marker = markers.single;
        final rawModule = marker.attributes['data-modname'] ?? '';
        final rawId = marker.attributes['data-modid'] ?? '';
        if (RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(rawModule) &&
            RegExp(r'^[1-9]\d*$').hasMatch(rawId)) {
          module = rawModule;
          moduleId = rawId;
          final identity = '$module:$moduleId';
          if (!identities.add(identity)) {
            throw const CoursemosParseException('duplicate_learning_identity');
          }
        }
        start = _nonemptyAttribute(marker, 'data-sterm');
        end = _nonemptyAttribute(marker, 'data-eterm');
      }
      final progress = RegExp(
        r'^(\d+(?:\.\d+)?)%$',
      ).firstMatch(_text(cells[4]));
      final percent = progress == null ? null : double.tryParse(progress[1]!);
      rows.add(
        CoursemosLearningRow(
          title: _text(cells[1]),
          module: module,
          moduleId: moduleId,
          rawOpenAt: start,
          rawDueAt: end,
          requiredLearningSeconds: parseDuration(_text(cells[2])),
          learnedSeconds: parseDuration(
            _text(cells[3]).replaceFirst(RegExp(r'\s*상세보기\s*\(\d+\)\s*$'), ''),
          ),
          progressPercent: percent != null && percent <= 100 ? percent : null,
        ),
      );
    }
    if (spans.isNotEmpty) {
      throw const CoursemosParseException('incomplete_learning_rowspan');
    }
    return CoursemosLearningIndex(
      rows: rows,
      rawRowCount: sourceRows.length,
      ignoredEmptyCount: ignoredEmpty,
      course: course,
      reportUrl: page.url,
    );
  }

  /// Unstudied report rows omit the detail button carrying identity/periods.
  /// Match only a unique, same-course resource with a verified module link and
  /// explicit displayed period. Missing learning time remains unknown, not zero.
  CoursemosLearningIndex recoverFromCourse(
    LmsHtmlPage page, {
    required CoursemosLearningIndex report,
  }) {
    if (page.url != report.course.url) {
      throw const CoursemosParseException('unexpected_learning_course');
    }
    final document = _document(page);
    if (!const {
      'page-course-view',
      'page-course-view-ubstopics',
      'page-course-view-ubsweeks',
    }.contains(document.body?.id)) {
      throw const CoursemosParseException('learning_course_structure_changed');
    }
    _checkPagination(document);
    final resources =
        <String, ({String title, String module, String start, String end})>{};
    for (final element in document.querySelectorAll(
      '#region-main li.activity.vod, #region-main li.activity.econtents',
    )) {
      final id = RegExp(r'^module-([1-9]\d*)$').firstMatch(element.id)?[1];
      if (id == null) continue;
      final module = element.classes.contains('vod') ? 'vod' : 'econtents';
      final linked = element.querySelectorAll('.activityinstance a[href]').any((
        anchor,
      ) {
        final url = _resolve(page.url, anchor.attributes['href']!);
        return url?.origin == page.url.origin &&
            url?.path == '/mod/$module/view.php' &&
            url?.queryParametersAll.length == 1 &&
            url?.queryParameters['id'] == id;
      });
      final name = element.querySelector('.instancename')?.clone(true);
      if (!linked || name == null) continue;
      for (final hidden in name.querySelectorAll('.accesshide')) {
        hidden.remove();
      }
      final periods = element
          .querySelectorAll('.contentafterlink, .displayoptions')
          .map(_text)
          .toSet();
      final parsed = <(String, String)>{};
      for (final text in periods) {
        final match = RegExp(
          r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) ~ (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}), \d+(?::\d{2}){1,2}$',
        ).firstMatch(text);
        if (match != null) parsed.add((match[1]!, match[2]!));
      }
      if (parsed.length != 1) continue;
      final period = parsed.single;
      final start = CoursemosParser.parseKoreanDate(period.$1)!;
      final end = CoursemosParser.parseKoreanDate(period.$2)!;
      if (!end.isAfter(start)) continue;
      final resource = (
        title: _text(name),
        module: module,
        start: (start.millisecondsSinceEpoch ~/ 1000).toString(),
        end: (end.millisecondsSinceEpoch ~/ 1000).toString(),
      );
      if (resources.containsKey(id) && resources[id] != resource) {
        throw const CoursemosParseException(
          'conflicting_learning_course_module',
        );
      }
      resources[id] = resource;
    }
    final recovered = [
      for (final row in report.rows) _recoverRow(row, resources),
    ];
    final identities = <String>{};
    for (final row in recovered.where((row) => row.hasRequiredFields)) {
      if (!identities.add(row.sourceIdentity!)) {
        throw const CoursemosParseException('ambiguous_learning_course_match');
      }
    }
    return CoursemosLearningIndex(
      rows: recovered,
      rawRowCount: report.rawRowCount,
      ignoredEmptyCount: report.ignoredEmptyCount,
      course: report.course,
      reportUrl: report.reportUrl,
      trackingUnavailable: report.trackingUnavailable,
    );
  }

  CoursemosLearningRow _recoverRow(
    CoursemosLearningRow row,
    Map<String, ({String title, String module, String start, String end})>
    resources,
  ) {
    if (row.hasRequiredFields || row.requiredLearningSeconds == 0) return row;
    final matches = resources.entries
        .where(
          (entry) =>
              entry.value.title == row.title &&
              (row.module == null || row.module == entry.value.module) &&
              (row.rawOpenAt == null || row.rawOpenAt == entry.value.start) &&
              (row.rawDueAt == null || row.rawDueAt == entry.value.end),
        )
        .toList();
    if (matches.length != 1) return row;
    final match = matches.single;
    return CoursemosLearningRow(
      title: row.title,
      module: match.value.module,
      moduleId: row.moduleId,
      courseModuleId: match.key,
      rawOpenAt: match.value.start,
      rawDueAt: match.value.end,
      requiredLearningSeconds: row.requiredLearningSeconds,
      learnedSeconds: row.learnedSeconds,
      progressPercent: row.progressPercent,
    );
  }

  /// Both period attributes in the authorized current SMU response are Unix
  /// seconds. Reject other formats rather than guessing a unit or time zone.
  static DateTime? parsePeriod(String? source) {
    if (source == null || !RegExp(r'^[1-9]\d{9}$').hasMatch(source)) {
      return null;
    }
    final seconds = int.parse(source);
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// The verified report uses minute:second durations; no bare number or missing
  /// time is converted to zero. Hours are explicit only in hour:minute:second.
  static int? parseDuration(String source) {
    // A literal zero was observed in the required-time cell. It is known zero,
    // not a schedulable learning requirement; missing learned time stays null.
    if (source.trim() == '0') return 0;
    final match = RegExp(
      r'^(\d+):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(source.trim());
    if (match == null) return null;
    final first = BigInt.tryParse(match[1]!);
    final second = int.parse(match[2]!);
    final third = match[3] == null ? null : int.parse(match[3]!);
    if (first == null || second > 59 || (third != null && third > 59)) {
      return null;
    }
    final seconds = third == null
        ? first * BigInt.from(60) + BigInt.from(second)
        : first * BigInt.from(3600) + BigInt.from(second * 60 + third);
    return seconds.isValidInt ? seconds.toInt() : null;
  }
}

String? _nonemptyAttribute(Element element, String name) {
  final value = element.attributes[name]?.trim();
  return value == null || value.isEmpty ? null : value;
}
