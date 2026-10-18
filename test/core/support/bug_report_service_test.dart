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

  test(
    'retries reuse the request ID and a different report gets a new one',
    () async {
      final seen = <String>[];
      var failNext = true;
      final client = MockClient((request) async {
        seen.add(request.headers['idempotency-key']!);
        if (failNext) {
          failNext = false;
          return http.Response('{"error":"upstream_unavailable"}', 503);
        }
        return http.Response(
          jsonEncode({
            'issueNumber': 7,
            'issueUrl': 'https://github.com/littlebit0/DailyCalendar/issues/7',
          }),
          201,
        );
      });
      final service = BugReportService(httpClient: client, endpoint: endpoint);
      const headers = {'Authorization': 'Bearer google-access-token'};

      await expectLater(
        service.submit(
          draft: draft,
          environment: environment,
          googleAuthorizationHeaders: headers,
        ),
        throwsA(isA<BugReportException>()),
      );
      await service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: headers,
      );
      expect(seen[0], seen[1]);

      // After a success the same text is a new, separate report.
      await service.submit(
        draft: draft,
        environment: environment,
        googleAuthorizationHeaders: headers,
      );
      expect(seen[2], isNot(seen[1]));

      await service.submit(
        draft: const BugReportDraft(
          title: '다른 제보',
          description: '다른 문제입니다.',
          reproductionSteps: '다른 단계',
          expectedBehavior: '다른 기대',
          actualBehavior: '다른 실제',
        ),
        environment: environment,
        googleAuthorizationHeaders: headers,
      );
      expect(seen[3], isNot(seen[2]));
    },
  );
}
