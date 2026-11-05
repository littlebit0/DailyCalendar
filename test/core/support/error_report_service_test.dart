import 'dart:async';
import 'dart:convert';

import 'package:daily/core/support/error_report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const environment = ErrorReportEnvironment(
    version: '6.1.0',
    buildNumber: '100',
    platform: 'macOS',
    osVersion: 'Version 27.2',
    deviceType: 'desktop',
    locale: 'ko-KR',
    timeZone: 'UTC+09:00',
    environment: 'production',
  );

  late SharedPreferences preferences;
  late List<http.Request> requests;
  late int status;
  late bool online;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    requests = [];
    status = 201;
    online = true;
    now = DateTime.utc(2026, 11, 5, 9);
  });

  ErrorReportService service({String buildMode = 'release'}) {
    final client = MockClient((request) async {
      if (!online) throw http.ClientException('offline');
      requests.add(request);
      return http.Response('{}', status);
    });
    return ErrorReportService(
      preferences: preferences,
      httpClient: client,
      endpoint: Uri.parse('https://errors.example.test/v1/error-reports'),
      now: () => now,
      environmentLoader: () async => environment,
      buildMode: buildMode,
    )..authorizationHeaders = () async => {'Authorization': 'Bearer google'};
  }

  Future<void> fail(
    ErrorReportService reports, {
    ErrorReportSeverity severity = ErrorReportSeverity.fatal,
    String message = 'Bad state: boom',
  }) {
    reports.record(
      StateError(message),
      StackTrace.current,
      feature: 'drive_sync',
      severity: severity,
    );
    return reports.flush();
  }

  test('masks tokens, emails, home folders, IDs and quoted user text', () {
    final cleaned = sanitizeErrorText(
      'Authorization: Bearer ya29.a0secret\n'
      'GET https://x.test/a?access_token=abc&user=kim\n'
      'refresh_token=1//0secret mail kim@example.com '
      'path /Users/kimhwi/Library C:\\Users\\kimhwi\\AppData '
      'event "치과 예약" id 3f2b1c4d-1111-4222-8333-123456789abc '
      'student 2026123456 phone 010-1234-5678 cookie: JSESSIONID=xyz',
    );
    for (final secret in [
      'ya29',
      'abc',
      '1//0secret',
      'kim@example.com',
      'kimhwi',
      '치과',
      '3f2b1c4d',
      '2026123456',
      '1234-5678',
      'JSESSIONID=xyz',
    ]) {
      expect(cleaned, isNot(contains(secret)), reason: secret);
    }
    expect(cleaned, contains('/Users/***'));
    expect(cleaned, contains('***@***'));
  });

  test('fingerprint ignores line numbers and changing IDs', () {
    String fingerprint(String stack, String message) => errorFingerprint(
      errorType: 'StateError',
      sanitizedStackTrace: stack,
      sanitizedMessage: message,
      feature: 'drive_sync',
      platform: 'macOS',
    );
    final a = fingerprint('#0 Foo.bar (package:daily/a.dart:10:3)', 'x 1');
    final b = fingerprint('#0 Foo.bar (package:daily/a.dart:42:7)', 'x 2');
    final c = fingerprint('#0 Foo.baz (package:daily/a.dart:10:3)', 'x 1');
    expect(a, b);
    expect(a, isNot(c));
    expect(a, matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('the same error ten times sends one report', () async {
    final reports = service();
    for (var i = 0; i < 10; i++) {
      await fail(reports);
    }
    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map<String, Object?>;
    expect(
      body.keys,
      unorderedEquals(['report', 'environment', 'integrations']),
    );
    expect(requests.single.headers['authorization'], 'Bearer google');
  });

  test('offline reports wait in the queue and go out later', () async {
    final reports = service();
    online = false;
    await fail(reports);
    expect(requests, isEmpty);
    online = true;
    await reports.flush();
    expect(requests, hasLength(1));
    await reports.flush();
    expect(requests, hasLength(1));
  });

  test('without a Google sign-in nothing is sent until one exists', () async {
    final reports = service()..authorizationHeaders = () async => null;
    await fail(reports);
    expect(requests, isEmpty);
    reports.authorizationHeaders = () async => {'Authorization': 'Bearer g'};
    await reports.flush();
    expect(requests, hasLength(1));
  });

  test('a receiver outage never throws and keeps the report', () async {
    final reports = service();
    status = 503;
    await fail(reports);
    final failedAttempts = requests.length;
    expect(failedAttempts, greaterThan(0));
    status = 201;
    await reports.flush();
    expect(requests, hasLength(failedAttempts + 1));
    await reports.flush();
    expect(requests, hasLength(failedAttempts + 1));
  });

  test('non-fatal errors are sent only once they repeat', () async {
    final reports = service();
    await fail(reports, severity: ErrorReportSeverity.nonFatal);
    await fail(reports, severity: ErrorReportSeverity.nonFatal);
    expect(requests, isEmpty);
    await fail(reports, severity: ErrorReportSeverity.nonFatal);
    expect(requests, hasLength(1));
    final report =
        (jsonDecode(requests.single.body) as Map)['report']
            as Map<String, Object?>;
    expect(report['occurrenceCount'], 3);
  });

  test('a crash loop is capped per day', () async {
    final reports = service();
    for (var i = 0; i < 30; i++) {
      // Distinct call sites give distinct fingerprints.
      reports.record(
        StateError('x'),
        StackTrace.fromString('#0 f$i (package:daily/a.dart:1:1)'),
        feature: 'app',
        severity: ErrorReportSeverity.fatal,
      );
      await reports.flush();
    }
    expect(requests, hasLength(ErrorReportService.maxReportsPerDay));
  });

  test('debug builds and disabled reporting send nothing', () async {
    await fail(service(buildMode: 'debug'));
    expect(requests, isEmpty);

    final reports = service();
    online = false;
    await fail(reports);
    await reports.setEnabled(false);
    online = true;
    await fail(reports);
    await reports.flush();
    expect(requests, isEmpty);
    expect(preferences.getString('errorReportQueue.v1'), isNull);
  });

  test('opting out while a send waits for sign-in stops it', () async {
    final reports = service();
    final gate = Completer<Map<String, String>?>();
    reports.authorizationHeaders = () => gate.future;
    reports.record(
      StateError('x'),
      StackTrace.current,
      feature: 'app',
      severity: ErrorReportSeverity.fatal,
    );
    await Future<void>.delayed(Duration.zero);
    final disabling = reports.setEnabled(false);
    gate.complete({'Authorization': 'Bearer g'});
    await disabling;
    await reports.flush();
    expect(requests, isEmpty);
    expect(preferences.getString('errorReportQueue.v1'), isNull);
  });

  test('reporting is on by default', () {
    expect(service().enabled, isTrue);
  });
}
