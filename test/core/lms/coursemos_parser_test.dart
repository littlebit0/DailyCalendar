import 'dart:io';

import 'package:daily/core/lms/coursemos_parser.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('test/fixtures/coursemos/$name.html').readAsStringSync();
LmsHtmlPage page(String path, String html) =>
    LmsHtmlPage(url: Uri.parse('https://ecampus.smu.ac.kr$path'), html: html);
final course = CoursemosCourse(
  id: '8001',
  title: '수업 8001',
  url: Uri.parse('https://ecampus.smu.ac.kr/course/view.php?id=8001'),
);

void main() {
  const parser = CoursemosParser();
  CoursemosActivityIndex assignments(String html) => parser.activities(
    page('/mod/assign/index.php?id=8001', html),
    course: course,
    type: 'assignment',
  );
  CoursemosActivityIndex quizzes(String html) => parser.activities(
    page('/mod/quiz/index.php?id=8001', html),
    course: course,
    type: 'quiz',
  );

  test(
    'verified dashboard retains all eleven courses without professor text',
    () {
      final courses = parser.courses(page('/', fixture('dashboard')));
      expect(courses, hasLength(11));
      expect(courses.map((course) => course.id).toSet(), hasLength(11));
      for (final course in courses) {
        expect(course.title, '수업 ${course.id}');
        expect(course.url.path, '/course/view.php');
        expect(course.url.queryParameters['id'], course.id);
      }
    },
  );

  test(
    'verified assignment table parses three tasks and two week dividers',
    () {
      final result = assignments(fixture('assignments'));
      expect(result.rawRowCount, 5);
      expect(result.ignoredHeadingCount, 2);
      expect(result.activities.map((activity) => activity.id), [
        '9001',
        '9002',
        '9003',
      ]);
      expect(result.activities.first.dueAt, DateTime.utc(2026, 10, 31, 14, 59));
      expect(result.activities.first.submissionStatus, '미제출');
    },
  );

  test('relative quiz detail links resolve against the index response URL', () {
    final result = quizzes(fixture('quizzes'));
    expect(result.activities, hasLength(2));
    expect(
      result.activities.first.url.toString(),
      'https://ecampus.smu.ac.kr/mod/quiz/view.php?id=9001',
    );
    expect(result.activities.first.dueAt, DateTime.utc(2026, 9, 14, 14, 59));
    expect(result.activities.last.dueAt, DateTime.utc(2026, 9, 28, 14, 59));
    expect(
      result.activities.every((activity) => activity.submissionStatus == null),
      isTrue,
    );
  });

  test(
    'verified empty quiz notice requires matching heading and return course',
    () {
      expect(quizzes(fixture('quizzes-empty')).activities, isEmpty);
      expect(
        () => quizzes(
          fixture('quizzes-empty').replaceAll('value="8001"', 'value="8002"'),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
      expect(
        () =>
            quizzes(fixture('quizzes-empty').replaceAll('퀴즈가 없습니다.', '새로운 안내')),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test('valid table with no data rows is a complete empty activity index', () {
    final html = fixture(
      'assignments',
    ).replaceFirst(RegExp(r'<tbody>[\s\S]*?</tbody>'), '<tbody></tbody>');
    expect(assignments(html).activities, isEmpty);
  });

  test(
    'verified empty assignment alert requires its exact marker and course return',
    () {
      final source = fixture('assignments-empty-alert');
      final result = assignments(source);
      expect(result.activities, isEmpty);
      expect(result.rawRowCount, 0);
      for (final changed in [
        source.replaceFirst('이 강좌에는 과제가 없습니다.', '이 강좌에 접근할 수 없습니다.'),
        source.replaceFirst('<h2>과제</h2>', '<h2>오류</h2>'),
        source.replaceFirst('alert alert-danger', 'unknown-notice'),
        source.replaceFirst('value="8001"', 'value="8002"'),
        source.replaceFirst('method="get"', 'method="post"'),
        source.replaceFirst(
          'https://ecampus.smu.ac.kr/course/view.php',
          'https://example.com/course/view.php',
        ),
      ]) {
        expect(
          () => assignments(changed),
          throwsA(isA<CoursemosParseException>()),
        );
      }
    },
  );

  test(
    'verified empty assignment table recognizes topic headers and its empty row',
    () {
      final result = assignments(fixture('assignments-empty'));
      expect(result.activities, isEmpty);
      expect(result.rawRowCount, 1);
      expect(result.ignoredEmptyCount, 1);
      expect(
        () => assignments(
          fixture(
            'assignments-empty',
          ).replaceFirst('colspan="5"', 'colspan="4"'),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test(
    'rowspan week cells keep subsequent deadline and status columns aligned',
    () {
      final source = fixture('quizzes');
      final html = source
          .replaceFirst(
            '<td class="cell c0"',
            '<td rowspan="2" class="cell c0"',
          )
          .replaceFirst(RegExp(r'<td class="cell c0"[^>]*>4주차[^<]*</td>'), '');
      final parsed = quizzes(html).activities;
      expect(parsed, hasLength(2));
      expect(parsed[1].title, '퀴즈 2');
      expect(parsed[1].dueAt, DateTime.utc(2026, 9, 28, 14, 59));
      expect(
        () => quizzes(html.replaceFirst('rowspan="2"', 'rowspan="3"')),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test(
    'unknown columns, malformed deadlines and unexplained rows fail closed',
    () {
      final source = fixture('assignment-single');
      for (final html in [
        source.replaceFirst('종료 일시', '새로운 날짜 열'),
        source.replaceFirst('2026-09-07 23:59', '2026-09-31 23:59'),
        source.replaceFirst('2026-09-07 23:59', '내일 밤'),
        source.replaceFirst(
          '/mod/assign/view.php?id=9001',
          '/new/activity.php?id=9001',
        ),
        source.replaceFirst(
          '</tbody>',
          '<tr><td colspan="5">읽지 못한 활동</td></tr></tbody>',
        ),
      ]) {
        expect(
          () => assignments(html),
          throwsA(isA<CoursemosParseException>()),
        );
      }
    },
  );

  test(
    'no deadline is retained explicitly instead of creating a guessed date',
    () {
      final result = assignments(
        fixture('assignment-single').replaceFirst('2026-09-07 23:59', '—'),
      );
      expect(result.activities, hasLength(1));
      expect(result.activities.single.dueAt, isNull);
      expect(result.activities.single.id, '9001');
    },
  );

  test(
    'login responses, other courses and cross-origin activities are rejected',
    () {
      expect(
        () => assignments(
          '<main id="region-main"><input type="password"></main>',
        ),
        throwsA(
          isA<CoursemosParseException>().having(
            (error) => error.authenticationRequired,
            'login',
            isTrue,
          ),
        ),
      );
      expect(
        () => parser.activities(
          page('/mod/assign/index.php?id=8002', fixture('assignments')),
          course: course,
          type: 'assignment',
        ),
        throwsA(isA<CoursemosParseException>()),
      );
      expect(
        () => assignments(
          fixture('assignments').replaceAll(
            'https://ecampus.smu.ac.kr/mod/assign/',
            'https://example.com/mod/assign/',
          ),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );

  test(
    'missing dashboard structure, unknown empty and pagination cannot prune courses',
    () {
      for (final html in [
        '<main id="region-main">아무 링크 없음</main>',
        '<main id="region-main"><div class="course_lists"></div></main>',
        fixture(
          'dashboard',
        ).replaceFirst('</main>', '<a rel="next" href="?page=2">다음</a></main>'),
        fixture(
          'dashboard',
        ).replaceFirst('/course/view.php?id=8001', '/new/course.php?id=8001'),
      ]) {
        expect(
          () => parser.courses(page('/', html)),
          throwsA(isA<CoursemosParseException>()),
        );
      }
    },
  );

  test(
    'Korean deadlines retain the same UTC instant at midnight and leap days',
    () {
      expect(
        CoursemosParser.parseKoreanDate('2026-09-27 00:00'),
        DateTime.utc(2026, 9, 26, 15),
      );
      expect(
        CoursemosParser.parseKoreanDate('2028-02-29 23:59:30'),
        DateTime.utc(2028, 2, 29, 14, 59, 30),
      );
      for (final value in [
        '2026-02-29 12:00',
        '2026-09-26 24:00',
        '2026-13-01 00:00',
      ]) {
        expect(
          () => CoursemosParser.parseKoreanDate(value),
          throwsA(isA<CoursemosParseException>()),
        );
      }
    },
  );
}
