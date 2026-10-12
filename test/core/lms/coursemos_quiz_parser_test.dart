import 'package:daily/core/lms/coursemos_parser.dart';
import 'package:daily/core/lms/lms_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quiz_test_fixture.dart';

void main() {
  const parser = CoursemosParser();
  CoursemosQuizStatus? parse(String source) => parser.quizStatus(
    LmsHtmlPage(url: quizFixtureActivity.url, html: source),
    activity: quizFixtureActivity,
  );
  test(
    'submitted attempt is complete independently of grade or later retry',
    () {
      for (final state in ['종료됨', '제출됨', 'Finished']) {
        expect(
          parse(
            quizFixtureHtml([
              '$state<span class="statedetails">제출일 fixture</span>',
              '진행 중',
            ]),
          )!.completed,
          isTrue,
        );
      }
    },
  );
  test('verified future opening restriction resolves absent attempt table', () {
    final source = quizFixtureHtml([]).replaceFirst(
      RegExp(r'<table.*?</table>', dotAll: true),
      '<div class="box quizinfo well"><p>2026-10-13 00:00 까지는 퀴즈를 이용할 수 없음</p></div>'
      '<div class="box quizattempt"><p>응시할 수 없는 퀴즈입니다.</p></div>',
    );
    CoursemosQuizStatus? status(String html, DateTime now) => parser.quizStatus(
      LmsHtmlPage(url: quizFixtureActivity.url, html: html),
      activity: quizFixtureActivity,
      now: now,
    );
    expect(status(source, DateTime.utc(2026, 10, 12))!.completed, isFalse);
    expect(status(source, DateTime.utc(2026, 10, 13)), isNull);
    expect(
      status(
        source.replaceFirst('응시할 수 없는 퀴즈입니다.', '임의 안내'),
        DateTime.utc(2026, 10, 12),
      ),
      isNull,
    );
  });
  test('unfinished, overdue and abandoned attempts stay incomplete', () {
    for (final state in [
      '진행 중',
      '기한 만료',
      '제출되지 않음',
      'In progress',
      'Overdue',
      'Never submitted',
    ]) {
      expect(parse(quizFixtureHtml([state]))!.completed, isFalse);
    }
  });
  test('unknown/grade-only/malformed states never invent completion', () {
    expect(parse(quizFixtureHtml(['알 수 없음'])), isNull);
    expect(parse(quizFixtureHtml(['100 / 100'])), isNull);
    expect(parse(quizFixtureHtml([])), isNull);
    expect(
      parse(quizFixtureHtml(['진행 중']).replaceFirst('<td>—</td>', '')),
      isNull,
    );
    expect(parse(quizFixtureHtml(['종료됨']).replaceFirst('진행 상황', '총점')), isNull);
  });
  test('verified matching first-attempt form proves not yet attempted', () {
    final source = quizFixtureHtml([]).replaceFirst(
      RegExp(r'<table.*?</table>', dotAll: true),
      '''
<div class="quizattempt"><div class="quizstartbuttondiv">
<form method="post" action="/mod/quiz/startattempt.php"><input name="cmid" value="9001"><button>응시</button></form>
</div></div>''',
    );
    expect(parse(source)!.completed, isFalse);
    expect(parse(source.replaceFirst('value="9001"', 'value="9002"')), isNull);
    expect(
      parse(
        source.replaceFirst(
          '<button>',
          '<input name="preview" value="1"><button>',
        ),
      ),
      isNull,
    );
    expect(
      parse(
        source.replaceFirst(
          '/mod/quiz/startattempt.php',
          'https://evil.example/mod/quiz/startattempt.php',
        ),
      ),
      isNull,
    );
  });
  test(
    'login, wrong course, redirect and paginated summaries are rejected',
    () {
      expect(
        () => parse(
          quizFixtureHtml([
            '종료됨',
          ]).replaceFirst('</main>', '<input type="password"></main>'),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
      expect(
        () =>
            parse(quizFixtureHtml(['종료됨']).replaceFirst('id=8001', 'id=8002')),
        throwsA(isA<CoursemosParseException>()),
      );
      expect(
        () => parse(
          quizFixtureHtml(['종료됨']).replaceFirst(
            '</main>',
            '<a rel="next" href="?page=2">다음</a></main>',
          ),
        ),
        throwsA(isA<CoursemosParseException>()),
      );
      expect(
        () => parser.quizStatus(
          LmsHtmlPage(
            url: Uri.parse('https://evil.example/mod/quiz/view.php?id=9001'),
            html: quizFixtureHtml(['종료됨']),
          ),
          activity: quizFixtureActivity,
        ),
        throwsA(isA<CoursemosParseException>()),
      );
    },
  );
}
