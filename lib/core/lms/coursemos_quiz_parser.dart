part of 'coursemos_parser.dart';

class CoursemosQuizStatus {
  const CoursemosQuizStatus(this.completed, this.label);
  final bool completed;
  final String label;
}

extension CoursemosQuizParser on CoursemosParser {
  /// Read the quiz landing page, never an attempt/review/answer page. Statuses
  /// follow Coursemos' documented submission states and Moodle's view table.
  /// Grades, review links and generic course-completion ticks are not evidence.
  CoursemosQuizStatus? quizStatus(
    LmsHtmlPage page, {
    required CoursemosActivity activity,
    DateTime? now,
  }) {
    if (activity.type != 'quiz' ||
        page.url != activity.url ||
        page.url.path != '/mod/quiz/view.php' ||
        page.url.queryParameters.length != 1 ||
        _numericId(page.url) != activity.id) {
      throw const CoursemosParseException('unexpected_quiz_detail');
    }
    final document = _document(page);
    if (document.body?.id != 'page-mod-quiz-view') {
      throw const CoursemosParseException('quiz_detail_structure_changed');
    }
    _checkPagination(document);
    final main = document.querySelector('#region-main, [role="main"]')!;
    final courseLinks = document.querySelectorAll('a[href]').any((anchor) {
      final url = _resolve(page.url, anchor.attributes['href']!);
      return url?.origin == page.url.origin &&
          url?.path == '/course/view.php' &&
          url?.queryParameters['id'] == activity.course.id;
    });
    if (!courseLinks) {
      throw const CoursemosParseException('quiz_course_mismatch');
    }
    final tables = main.querySelectorAll('table.quizattemptsummary');
    if (tables.length > 1) return null;
    if (tables.isEmpty) {
      // The verified SMU page omits both the table and POST start form before
      // opening. Its explicit future opening restriction is independent proof
      // that the student cannot yet have attempted this quiz.
      final unavailable = main
          .querySelectorAll('.quizattempt p')
          .any((element) => _text(element) == '응시할 수 없는 퀴즈입니다.');
      if (unavailable) {
        for (final notice in main.querySelectorAll('.quizinfo p')) {
          final match = RegExp(
            r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}) 까지는 퀴즈를 이용할 수 없음$',
          ).firstMatch(_text(notice));
          final opens = match == null
              ? null
              : CoursemosParser.parseKoreanDate(match[1]!);
          if (opens != null && opens.isAfter((now ?? DateTime.now()).toUtc())) {
            return const CoursemosQuizStatus(false, '미응시');
          }
        }
      }
      // Moodle emits no attempt table for a learner who has never started.
      // Require its matching first-attempt POST form, never just an absent row.
      final starts = main.querySelectorAll(
        '.quizattempt .quizstartbuttondiv form',
      );
      for (final form in starts) {
        final action = _resolve(page.url, form.attributes['action'] ?? '');
        if (form.attributes['method']?.toLowerCase() == 'post' &&
            action?.origin == page.url.origin &&
            action?.path == '/mod/quiz/startattempt.php' &&
            form.querySelector('input[name="cmid"]')?.attributes['value'] ==
                activity.id &&
            form.querySelector('input[name="preview"]') == null &&
            form.querySelector('input[name="attempt"]') == null) {
          return const CoursemosQuizStatus(false, '미응시');
        }
      }
      return null;
    }
    final table = tables.single;
    final headers = table.querySelectorAll('thead th');
    final stateColumns = <int>[];
    for (var i = 0; i < headers.length; i++) {
      if (const {'진행 상황', '진행상황', '상태', 'State'}.contains(_text(headers[i]))) {
        stateColumns.add(i);
      }
    }
    if (stateColumns.length != 1) return null;
    final states = <String>[];
    final rows = table.querySelectorAll('tbody tr');
    if (rows.isEmpty) return null;
    for (final row in rows) {
      final cells = row.children
          .where((cell) => cell.localName == 'td')
          .toList();
      if (cells.length != headers.length ||
          cells.any(
            (cell) =>
                cell.attributes.containsKey('colspan') ||
                cell.attributes.containsKey('rowspan'),
          )) {
        return null;
      }
      final state = cells[stateColumns.single].clone(true);
      for (final detail in state.querySelectorAll('.statedetails')) {
        detail.remove();
      }
      states.add(_text(state));
    }
    if (states.any(const {'종료됨', '제출됨', 'Finished'}.contains)) {
      return const CoursemosQuizStatus(true, '제출 완료');
    }
    const incomplete = {
      '진행 중',
      '진행중',
      '기한 만료',
      '제출되지 않음',
      'In progress',
      'Overdue',
      'Never submitted',
    };
    if (!states.every(incomplete.contains)) return null;
    final label = switch (states.last) {
      '진행 중' || '진행중' || 'In progress' => '진행 중',
      '기한 만료' || 'Overdue' => '기한 만료',
      _ => '제출되지 않음',
    };
    return CoursemosQuizStatus(false, label);
  }
}
