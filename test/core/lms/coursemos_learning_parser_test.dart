import 'package:daily/core/lms/coursemos_parser.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Structure and duration samples are from the retained 2026-09-26 anonymized
// progress-shape evidence; identifiers and titles below are test-only values.
const _shape = '''
<main id="region-main"><div id="ubcompletion-progress-wrapper">
<table class="progressreport user_progress"><thead><tr>
<th>주</th><th>강의 자료</th><th>출석인정 요구시간</th>
<th>총 학습시간</th><th>진도율</th></tr></thead><tbody>
<tr><td rowspan="2">1</td><td>자료 A</td><td>09:27</td>
<td>10:31 <a class="track_detail">상세보기 (1)</a></td><td>100%</td></tr>
<tr><td>자료 B</td><td>11:03</td>
<td>12:18 <a class="track_detail">상세보기 (1)</a></td><td>100%</td></tr>
</tbody></table></div></main>
''';

// Authorized 2026-09-29 report values, with test-only titles and source IDs.
// In particular, source completion must not use the progress percentage.
const _currentShape = '''
<main id="region-main"><div id="ubcompletion-progress-wrapper">
<table class="progressreport user_progress"><thead><tr>
<th>주</th><th>강의 자료</th><th>출석인정 요구시간</th>
<th>총 학습시간</th><th>진도율</th></tr></thead><tbody>
<tr><td rowspan="2">4</td><td>자료 A</td><td>36:00</td>
<td>01:00:48<br><button class="track_detail" data-modname="econtents"
data-modid="9001" data-sterm="1790521200" data-eterm="1791125940"
data-progresstime="1">상세보기 (2)</button></td><td>100%</td>
<tr><td>자료 B</td><td>18:00</td>
<td>18:23<br><button class="track_detail" data-modname="econtents"
data-modid="9002" data-sterm="1790521200" data-eterm="1791125940"
data-progresstime="1">상세보기 (1)</button></td><td>91.92%</td></tr>
<tr><td>5</td><td></td><td></td><td></td><td></td></tr>
</tbody></table></div></main>
''';

void main() {
  const parser = CoursemosLearningParser();
  final course = CoursemosCourse(
    id: '8001',
    title: '수업',
    url: Uri.parse('https://ecampus.smu.ac.kr/course/view.php?id=8001'),
  );
  CoursemosLearningIndex parse(String html, {String? path}) => parser.parse(
    LmsHtmlPage(
      url: Uri.parse(
        'https://ecampus.smu.ac.kr${path ?? '/report/ubcompletion/user_progress.php?id=8001'}',
      ),
      html: html,
    ),
    course: course,
  );

  test(
    'explicit tracking-disabled response is not a failed or prunable report',
    () {
      final report = parse(
        '<main id="region-main">'
        '<div id="ubcompletion-progress-wrapper"><div class="alert alert-danger">'
        '등록된 학습자원/활동이 존재하지 않거나, 진도관리가 활성화된 학습자원/활동이 없습니다.'
        '</div></div></main>',
      );
      expect(report.trackingUnavailable, isTrue);
      expect(report.coverageComplete, isTrue);
      expect(report.activities, isEmpty);
      expect(
        () => parse(
          '<main id="region-main"><div id="ubcompletion-progress-wrapper">'
          '<div class="alert alert-danger">알 수 없는 오류</div></div></main>',
        ),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test(
    'unique course resource recovers real dates without inventing learning time',
    () {
      final pending = parse(_shape.replaceFirst('10:31', ''));
      const body =
          '<html><body id="page-course-view"><main id="region-main">'
          '<li class="activity vod modtype_vod" id="module-7001">'
          '<div class="activityinstance"><a href="/mod/vod/view.php?id=7001">'
          '<span class="instancename">자료 A<span class="accesshide">동영상</span></span>'
          '</a></div><div class="contentafterlink">'
          '2026-10-01 00:00:00 ~ 2026-10-18 23:59:00, 10:30'
          '</div></li></main></body></html>';
      CoursemosLearningIndex recover(String source) => parser.recoverFromCourse(
        LmsHtmlPage(url: course.url, html: source),
        report: pending,
      );
      for (final format in [
        'page-course-view-ubstopics',
        'page-course-view-ubsweeks',
      ]) {
        final liveShape = body
            .replaceFirst('page-course-view', format)
            .replaceFirst('contentafterlink', 'displayoptions');
        expect(recover(liveShape).activities, hasLength(1));
      }
      final fixed = recover(body);
      expect(fixed.unresolvedRowCount, 1);
      expect(fixed.activities.single.id, 'report:cm:vod:7001');
      expect(fixed.activities.single.openAt, DateTime.utc(2026, 9, 30, 15));
      expect(fixed.activities.single.dueAt, DateTime.utc(2026, 10, 18, 14, 59));
      expect(fixed.activities.single.learnedSeconds, isNull);
      expect(fixed.activities.single.sourceCompleted, isNull);
      expect(fixed.activities.single.url.fragment, 'module-7001');
      final resource = RegExp(
        r'<li.*?</li>',
        dotAll: true,
      ).firstMatch(body)!.group(0)!;
      final ambiguous = body.replaceFirst(
        '</main>',
        '${resource.replaceAll('7001', '7002')}</main>',
      );
      expect(recover(ambiguous).activities, isEmpty);
      final duplicateReport = parse(_shape.replaceFirst('자료 B', '자료 A'));
      expect(
        () => parser.recoverFromCourse(
          LmsHtmlPage(url: course.url, html: body),
          report: duplicateReport,
        ),
        throwsA(isA<CoursemosParseException>()),
      );

      expect(
        recover(
          body.replaceFirst('/mod/vod/view.php', '/mod/quiz/attempt.php'),
        ).activities,
        isEmpty,
      );
      expect(recover(body.replaceFirst('자료 A', '다른 자료')).activities, isEmpty);
    },
  );
  test(
    'rowspans preserve required and learned time without treating IDs as known',
    () {
      final report = parse(_shape);
      expect(report.rawRowCount, 2);
      expect(report.rows.map((row) => row.requiredLearningSeconds), [567, 663]);
      expect(report.rows.map((row) => row.learnedSeconds), [631, 738]);
      expect(report.rows.map((row) => row.progressPercent), [100, 100]);
      expect(report.rows.every((row) => row.sourceIdentity == null), isTrue);
      expect(report.unresolvedRowCount, 2);
      expect(report.coverageComplete, isFalse);
    },
  );

  test('report module identity and period attributes remain opaque', () {
    final html = _shape
        .replaceFirst('class="track_detail">', '''class="track_detail"
        data-modname="vod" data-modid="9001"
        data-sterm="period-start" data-eterm="period-end">''')
        .replaceFirst('class="track_detail">', '''class="track_detail"
        data-modname="contents" data-modid="9002"
        data-sterm="another-start" data-eterm="another-end">''');
    final report = parse(html);
    // Replace markers independently to avoid interpreting IDs as view.php IDs.
    expect(report.rows.first.sourceIdentity, 'vod:9001');
    expect(report.rows.first.rawOpenAt, 'period-start');
    expect(report.rows.first.rawDueAt, 'period-end');
    expect(report.rows.last.sourceIdentity, 'contents:9002');
    expect(report.coverageComplete, isFalse);
    expect(report.activities, isEmpty);
  });

  test(
    'verified period, identity and required time produce source activities',
    () {
      final report = parse(_currentShape);
      expect(report.rawRowCount, 3);
      expect(report.ignoredEmptyCount, 1);
      expect(report.rows, hasLength(2));
      expect(report.unresolvedRowCount, 0);
      expect(report.coverageComplete, isTrue);
      final activities = report.activities;
      expect(activities.map((activity) => activity.id), [
        'report:econtents:9001',
        'report:econtents:9002',
      ]);
      expect(
        activities.every((activity) => activity.type == 'lecture'),
        isTrue,
      );
      expect(activities.first.course, same(course));
      expect(activities.first.openAt, DateTime.utc(2026, 9, 27, 15));
      expect(activities.first.dueAt, DateTime.utc(2026, 10, 4, 14, 59));
      expect(activities.first.openAt!.isUtc, isTrue);
      expect(activities.first.requiredLearningSeconds, 2160);
      expect(activities.first.learnedSeconds, 3648);
      expect(activities.last.requiredLearningSeconds, 1080);
      expect(activities.last.learnedSeconds, 1103);
      expect(activities.last.progressPercent, 91.92);
      expect(
        activities.every((activity) => activity.sourceCompleted == true),
        isTrue,
      );
      expect(
        activities.every((activity) => activity.attendanceStatus == null),
        isTrue,
      );
      expect(
        activities.every((activity) => activity.url == report.reportUrl),
        isTrue,
      );
      expect(report.reportUrl.path, '/report/ubcompletion/user_progress.php');
    },
  );

  test(
    'incomplete learning time remains incomplete despite a full percentage',
    () {
      final report = parse(_currentShape.replaceFirst('01:00:48', '05:17'));
      expect(report.activities.first.sourceCompleted, isFalse);
      expect(report.activities.first.learnedSeconds, 317);
      expect(report.activities.first.progressPercent, 100);
    },
  );

  test(
    'unknown named rows prevent full coverage without guessing missing time',
    () {
      final html = _currentShape.replaceFirst(
        '<tr><td>5</td><td></td><td></td><td></td><td></td></tr>',
        '<tr><td>5</td><td>미학습 자료</td><td>27:00</td><td></td><td>-</td></tr>',
      );
      final report = parse(html.replaceFirst('<th>주</th>', '<th>주제</th>'));
      expect(report.rows, hasLength(3));
      expect(report.rows.last.learnedSeconds, isNull);
      expect(report.rows.last.sourceIdentity, isNull);
      expect(report.unresolvedRowCount, 1);
      expect(report.coverageComplete, isFalse);
      expect(report.activities, hasLength(2));
    },
  );

  test(
    'source modules separate report identities without fabricating links',
    () {
      final report = parse(
        _currentShape
            .replaceFirst('data-modname="econtents"', 'data-modname="vod"')
            .replaceFirst('data-modid="9002"', 'data-modid="9001"'),
      );
      expect(report.activities.map((activity) => activity.id), [
        'report:vod:9001',
        'report:econtents:9001',
      ]);
      expect(
        () => parse(
          _currentShape.replaceFirst('data-modid="9002"', 'data-modid="9001"'),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test(
    'unsupported module, absent time and invalid periods remain unresolved',
    () {
      for (final html in [
        _currentShape.replaceFirst(
          'data-modname="econtents"',
          'data-modname="unknown"',
        ),
        _currentShape.replaceFirst('data-modid="9001"', 'data-modid="0"'),
        _currentShape.replaceFirst('data-sterm="1790521200"', ''),
        _currentShape.replaceFirst('1790521200', '1790521200000'),
        _currentShape.replaceFirst('1790521200', 'not-a-date'),
        _currentShape.replaceFirst('1790521200', '1791125940'),
        _currentShape.replaceFirst('1790521200', '1791125941'),
        _currentShape.replaceFirst('01:00:48', ''),
      ]) {
        final report = parse(html);
        expect(report.unresolvedRowCount, 1);
        expect(report.coverageComplete, isFalse);
        expect(report.activities.map((activity) => activity.id), [
          'report:econtents:9002',
        ]);
      }
    },
  );

  test(
    'known zero requirement excludes reference rows without a missing-data warning',
    () {
      for (final requirement in ['0', '00:00']) {
        final html = _currentShape.replaceFirst(
          RegExp(r'<tbody>[\s\S]*?</tbody>'),
          '<tbody><tr><td>1</td><td>참고 자료</td><td>$requirement</td><td></td><td>-</td></tr></tbody>',
        );
        final report = parse(html);
        expect(report.activities, isEmpty);
        expect(report.rows.single.sourceIdentity, isNull);
        expect(report.rows.single.openAt, isNull);
        expect(report.excludedNonAttendanceCount, 1);
        expect(report.unresolvedRowCount, 0);
        expect(report.coverageComplete, isTrue);
        final unknown = parse(
          html.replaceFirst('<td>$requirement</td>', '<td></td>'),
        );
        expect(unknown.excludedNonAttendanceCount, 0);
        expect(unknown.unresolvedRowCount, 1);
        expect(unknown.coverageComplete, isFalse);
      }
    },
  );

  test(
    'unrecognized table, principal page, course and pagination fail closed',
    () {
      for (final html in [
        _shape.replaceFirst('총 학습시간', '다른 시간'),
        _shape.replaceFirst('user_progress', 'unknown_report'),
        '<input type="password">$_shape',
        '$_shape<a rel="next" href="?page=2">next</a>',
        _shape.replaceFirst('rowspan="2"', 'rowspan="3"'),
      ]) {
        expect(() => parse(html), throwsA(isA<CoursemosParseException>()));
      }
      expect(
        () => parse(
          _shape,
          path: '/report/ubcompletion/user_progress.php?id=8002',
        ),
        throwsA(isA<CoursemosParseException>()),
      );
      for (final suffix in ['&id=8001', '&page=2', '#other']) {
        expect(
          () => parse(
            _shape,
            path: '/report/ubcompletion/user_progress.php?id=8001$suffix',
          ),
          throwsA(isA<CoursemosParseException>()),
        );
      }
    },
  );

  test(
    'unverified empty table and missing time never imply complete coverage',
    () {
      final empty = _shape.replaceFirst(
        RegExp(r'<tbody>[\s\S]*?</tbody>'),
        '<tbody></tbody>',
      );
      expect(parse(empty).coverageComplete, isFalse);
      final missing = parse(_shape.replaceFirst('10:31', ''));
      expect(missing.rows.first.learnedSeconds, isNull);
      expect(missing.unresolvedRowCount, 2);
    },
  );

  test(
    'durations distinguish a zero record from an absent or malformed record',
    () {
      for (final value in [
        '',
        '-',
        '100%',
        '5',
        '-1:00',
        '00:60',
        '01:60:00',
      ]) {
        expect(CoursemosLearningParser.parseDuration(value), isNull);
      }
      expect(CoursemosLearningParser.parseDuration('00:00'), 0);
      expect(CoursemosLearningParser.parseDuration('0'), 0);
      expect(CoursemosLearningParser.parseDuration('09:27'), 567);
      expect(CoursemosLearningParser.parseDuration('60:00'), 3600);
      expect(CoursemosLearningParser.parseDuration('01:02:03'), 3723);
    },
  );
}
