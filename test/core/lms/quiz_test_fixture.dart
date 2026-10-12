import 'package:daily/core/lms/coursemos_parser.dart';

final quizFixtureActivity = CoursemosActivity(
  id: '9001',
  title: 'Fixture quiz',
  type: 'quiz',
  url: Uri.parse('https://ecampus.smu.ac.kr/mod/quiz/view.php?id=9001'),
  course: CoursemosCourse(
    id: '8001',
    title: 'Fixture course',
    url: Uri.parse('https://ecampus.smu.ac.kr/course/view.php?id=8001'),
  ),
);

// Synthetic fixtures follow Moodle renderer view_table/attempt_state and the
// Coursemos official state definitions, not captured personal answers/grades.
String quizFixtureHtml(List<String> states) =>
    '''<body id="page-mod-quiz-view">
<nav><a href="/user/edit.php?id=70001">계정</a>
<a href="/course/view.php?id=8001">강좌</a></nav><main id="region-main">
<table class="generaltable quizattemptsummary"><thead><tr>
<th>응시</th><th>진행 상황</th><th>성적</th></tr></thead><tbody>
${states.map((state) => '<tr><td>1</td><td>$state</td><td>—</td></tr>').join()}
</tbody></table></main></body>''';
