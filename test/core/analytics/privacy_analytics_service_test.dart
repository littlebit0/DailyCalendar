import 'dart:convert';

import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  const environment = AnalyticsEnvironment(
    appVersion: '3.1.0',
    platform: 'ios',
    osMajor: 26,
  );

  for (final packageName in [
    'com.littlebit0.daily',
    'com.littlebit0.daily.test',
  ]) {
    test('analytics labels the actual version for $packageName', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Daily',
        packageName: packageName,
        version: '4.1.2',
        buildNumber: '42',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({
        'anonymousAnalyticsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final batches = <Map<String, dynamic>>[];
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        endpoint: Uri.parse('https://analytics.example.com/v1/events'),
        httpClient: MockClient((request) async {
          batches.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 202);
        }),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.record(AnalyticsRecord.appLoad(durationMs: 25));
      await service.flush();
      expect(batches, hasLength(1));
      expect(
        (batches.single['environment'] as Map)['appVersion'],
        packageName.endsWith('.test') ? '4.1.2-test' : '4.1.2',
      );
      expect(isSafeAnalyticsBatch(batches.single), isTrue);
    });
  }

  test('analytics is opt-in and records nothing before consent', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var requests = 0;
    final service = PrivacyAnalyticsService(
      preferences: preferences,
      endpoint: Uri.parse('http://localhost/v1/events'),
      environmentLoader: () async => environment,
      httpClient: MockClient((request) async {
        requests += 1;
        return http.Response('', 202);
      }),
    );
    addTearDown(service.dispose);

    await service.initialize();
    await service.record(AnalyticsRecord.screenView(AnalyticsScreen.calendar));
    await service.flush();

    expect(service.enabled, isFalse);
    expect(service.consentPromptCompleted, isFalse);
    expect(service.pendingEventCount, 0);
    expect(requests, 0);
  });

  test(
    'consent choice is persisted without enabling declined analytics',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        environmentLoader: () async => environment,
      );
      addTearDown(service.dispose);

      await service.initialize();
      await service.completeConsentPrompt(enabled: false);

      expect(service.enabled, isFalse);
      expect(service.consentPromptCompleted, isTrue);
      expect(
        preferences.getBool('anonymousAnalyticsConsentPromptCompletedV1'),
        isTrue,
      );
    },
  );

  test(
    'an existing explicit analytics preference counts as consent history',
    () async {
      SharedPreferences.setMockInitialValues({
        'anonymousAnalyticsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        environmentLoader: () async => environment,
      );
      addTearDown(service.dispose);

      expect(service.enabled, isTrue);
      expect(service.consentPromptCompleted, isTrue);
    },
  );

  test(
    'environment lookup failure never blocks analytics initialization',
    () async {
      SharedPreferences.setMockInitialValues({
        'anonymousAnalyticsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        environmentLoader: () async => throw StateError('package unavailable'),
      );
      addTearDown(service.dispose);

      await expectLater(service.initialize(), completes);
      await expectLater(
        service.record(AnalyticsRecord.appLoad(durationMs: 420)),
        completes,
      );

      expect(service.pendingEventCount, 1);
    },
  );

  test('consented payload contains only anonymous allowlisted data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    Map<String, Object?>? payload;
    final service = PrivacyAnalyticsService(
      preferences: preferences,
      endpoint: Uri.parse('http://localhost/v1/events'),
      environmentLoader: () async => environment,
      httpClient: MockClient((request) async {
        payload = Map<String, Object?>.from(jsonDecode(request.body) as Map);
        return http.Response('', 202);
      }),
    );
    addTearDown(service.dispose);

    await service.initialize();
    await service.setEnabled(true);
    await service.record(
      AnalyticsRecord.calendarViewChanged(
        AnalyticsCalendarView.month,
        trigger: AnalyticsTrigger.manual,
      ),
    );
    await service.flush();

    expect(payload, isNotNull);
    expect(isSafeAnalyticsBatch(payload), isTrue);
    final encoded = jsonEncode(payload).toLowerCase();
    for (final forbidden in [
      'event title',
      'memo text',
      '@example.com',
      'access_token',
      'deviceid',
    ]) {
      expect(encoded, isNot(contains(forbidden)));
    }
    expect(service.pendingEventCount, 0);
  });

  test('unsafe free-text attributes are rejected by the schema', () {
    final unsafe = {
      'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'name': 'screen_view',
      'occurredAt': '2026-08-21T00:00:00.000Z',
      'attributes': {'screen': 'calendar', 'title': 'private schedule'},
    };

    expect(isSafeAnalyticsEvent(unsafe), isFalse);
  });

  test(
    'duplicate events are suppressed and offline events remain queued',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        endpoint: Uri.parse('http://localhost/v1/events'),
        environmentLoader: () async => environment,
        httpClient: MockClient((request) async {
          throw http.ClientException('offline', request.url);
        }),
      );
      addTearDown(service.dispose);

      await service.initialize();
      await service.setEnabled(true);
      final record = AnalyticsRecord.screenView(AnalyticsScreen.search);
      await service.record(record);
      await service.record(record);
      await service.flush();

      expect(service.pendingEventCount, 1);
      expect(preferences.getString('anonymousAnalyticsQueueV1'), isNotEmpty);
    },
  );

  test('offline queue is bounded and disabling deletes queued data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var now = DateTime.utc(2026, 8, 21);
    final service = PrivacyAnalyticsService(
      preferences: preferences,
      environmentLoader: () async => environment,
      now: () {
        final value = now;
        now = now.add(const Duration(seconds: 2));
        return value;
      },
    );
    addTearDown(service.dispose);

    await service.initialize();
    await service.setEnabled(true);
    for (var index = 0; index < 205; index += 1) {
      await service.record(
        AnalyticsRecord.featureUsed(
          AnalyticsFeature.widget,
          outcome: index.isEven
              ? AnalyticsOutcome.succeeded
              : AnalyticsOutcome.failed,
        ),
      );
    }

    expect(service.pendingEventCount, 200);
    await service.setEnabled(false);
    expect(service.pendingEventCount, 0);
    expect(preferences.getString('anonymousAnalyticsQueueV1'), isNull);
  });

  test(
    'a retry after the retention period does not resend expired events',
    () async {
      SharedPreferences.setMockInitialValues({
        'anonymousAnalyticsEnabled': true,
      });
      final preferences = await SharedPreferences.getInstance();
      var now = DateTime.utc(2026, 10, 1, 12);
      var accept = false;
      var posts = 0;
      final service = PrivacyAnalyticsService(
        preferences: preferences,
        endpoint: Uri.parse('https://analytics.example.com/v1/events'),
        environmentLoader: () async => environment,
        now: () => now,
        httpClient: MockClient((request) async {
          posts += 1;
          return http.Response('{}', accept ? 202 : 503);
        }),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.record(AnalyticsRecord.appLoad(durationMs: 25));
      await service.flush();
      expect(posts, 1);

      // Eight days later nothing new was recorded, and only the retry runs.
      now = now.add(const Duration(days: 8));
      accept = true;
      await service.flush();
      expect(posts, 1, reason: 'the expired event must not be sent');
      expect(preferences.getString('anonymousAnalyticsQueueV1'), isNull);
    },
  );
}
