import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _event(Map<String, Object?> attributes) => {
  'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'name': 'lms_login',
  'occurredAt': '2026-10-19T00:00:00Z',
  'attributes': attributes,
};

void main() {
  test('failed needs a cause, skipped needs a reason, others carry neither', () {
    bool valid(Map<String, Object?> attributes) =>
        isSafeAnalyticsEvent(_event(attributes));
    const base = {'method': 'automatic', 'stage': 'authentication'};

    expect(valid({...base, 'result': 'succeeded'}), isTrue);
    expect(valid({...base, 'result': 'canceled'}), isTrue);
    expect(valid({...base, 'result': 'failed', 'cause': 'timedOut'}), isTrue);
    expect(valid({...base, 'result': 'failed'}), isFalse);
    expect(valid({...base, 'result': 'succeeded', 'cause': 'timedOut'}), isFalse);
    expect(valid({...base, 'result': 'skipped', 'skipReason': 'paused'}), isTrue);
    expect(valid({...base, 'result': 'skipped'}), isFalse);
    expect(
      valid({...base, 'result': 'failed', 'cause': 'timedOut', 'skipReason': 'paused'}),
      isFalse,
    );
  });

  test('free text, unknown codes and extra fields are rejected', () {
    const ok = {
      'method': 'manual',
      'stage': 'prepare',
      'result': 'failed',
      'cause': 'network',
    };
    expect(isSafeAnalyticsEvent(_event(ok)), isTrue);
    for (final bad in [
      {...ok, 'cause': 'Exception: 401 for user kim@example.com'},
      {...ok, 'cause': 'wrongPassword'},
      {...ok, 'stage': 'https://school.example/login?ticket=1'},
      {...ok, 'method': 'sso'},
      {...ok, 'username': 'kim'},
      {...ok, 'url': 'https://school.example/'},
    ]) {
      expect(isSafeAnalyticsEvent(_event(bad)), isFalse, reason: '$bad');
    }
  });

  test('records coerce anything unknown to fixed safe codes', () {
    final record = AnalyticsRecord.lmsLogin(
      method: AnalyticsLmsMethod.manual,
      stage: AnalyticsLmsStage.authentication,
      result: AnalyticsLmsResult.failed,
      cause: 'password=hunter2',
    );
    expect(record.attributes['cause'], 'unknown');
    final succeeded = AnalyticsRecord.lmsLogin(
      method: AnalyticsLmsMethod.manual,
      stage: AnalyticsLmsStage.session,
      result: AnalyticsLmsResult.succeeded,
      cause: 'timedOut',
      skipReason: AnalyticsLmsSkipReason.paused,
    );
    expect(succeeded.attributes.keys, {'method', 'stage', 'result'});
  });
}
