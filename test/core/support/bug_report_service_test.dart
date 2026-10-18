import 'dart:convert';

import 'package:daily/core/support/bug_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const environment = BugReportEnvironment(
    version: '3.2.0',
    buildNumber: '3.2.0',
    platform: 'iOS',
    osVersion: 'iOS 26.5.2',
  );
  const draft = BugReportDraft(
    title: '일정 저장 실패',
    description: '저장한 일정이 월간 화면에 보이지 않습니다.',
    reproductionSteps: '일정을 추가한 뒤 저장을 누릅니다.',
    expectedBehavior: '월간 화면에 일정이 표시됩니다.',
    actualBehavior: '일정이 표시되지 않습니다.',
  );
  final endpoint = Uri.parse('https://bugs.example.test/v1/bug-reports');

  test(
    'submits the report with Google authorization but without an email',
    () async {
      final client = MockClient((request) async {
        expect(request.url, endpoint);
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer google-access-token');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body.keys, unorderedEquals(['report', 'environment']));
        expect(request.body, isNot(contains('daily-user@example.com')));
        expect((body['report']! as Map)['title'], '일정 저장 실패');
        expect((body['environment']! as Map)['platform'], 'iOS');
        return http.Response(
          jsonEncode({
            'issueNumber': 321,
            'issueUrl':
                'https://github.com/littlebit0/DailyCalendar/issues/321',
          }),
          201,
        );
      });
      final service = BugReportService(httpClient: client, endpoint: endpoint);

      final submission = await service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: const {
          'Authorization': 'Bearer google-access-token',
        },
      );

      expect(submission.issueNumber, 321);
      expect(
        submission.issueUrl,
        Uri.parse('https://github.com/littlebit0/DailyCalendar/issues/321'),
      );
    },
  );

  test('does not send a report without Google bearer authorization', () async {
    final service = BugReportService(
      httpClient: MockClient((_) async => throw StateError('must not send')),
      endpoint: endpoint,
    );

    await expectLater(
      service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: const {},
      ),
      throwsA(
        isA<BugReportException>().having(
          (error) => error.code,
          'code',
          'google_auth_required',
        ),
      ),
    );
  });

  test('keeps a rejected Google token as a failed submission', () async {
    final service = BugReportService(
      httpClient: MockClient(
        (_) async =>
            http.Response(jsonEncode({'error': 'invalid_google_token'}), 401),
      ),
      endpoint: endpoint,
    );

    await expectLater(
      service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: const {
          'Authorization': 'Bearer expired-token',
        },
      ),
      throwsA(
        isA<BugReportException>().having(
          (error) => error.code,
          'code',
          'invalid_google_token',
        ),
      ),
    );
  });

  test('refuses a body over the receiver limit before sending it', () async {
    var sent = false;
    final service = BugReportService(
      httpClient: MockClient((_) async {
        sent = true;
        return http.Response('', 500);
      }),
      endpoint: endpoint,
    );
    final huge = BugReportDraft(
      title: draft.title,
      description: '😀' * 20000,
      reproductionSteps: draft.reproductionSteps,
      expectedBehavior: draft.expectedBehavior,
      actualBehavior: draft.actualBehavior,
    );
    await expectLater(
      service.submit(
        draft: huge,
        environment: environment,
        googleAuthorizationHeaders: const {'Authorization': 'Bearer t'},
      ),
      throwsA(
        isA<BugReportException>().having((e) => e.code, 'code', 'invalid_size'),
      ),
    );
    expect(sent, isFalse);
  });

  test('a 413 answer is explained, not shown as a generic failure', () async {
    final service = BugReportService(
      httpClient: MockClient(
        (_) async => http.Response('{"error":"invalid_size"}', 413),
      ),
      endpoint: endpoint,
    );
    await expectLater(
      service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: const {'Authorization': 'Bearer t'},
      ),
      throwsA(
        isA<BugReportException>().having(
          (e) => e.message,
          'message',
          contains('너무 깁니다'),
        ),
      ),
    );
  });
}
