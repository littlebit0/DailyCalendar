import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _event(AnalyticsRecord record, [Map<String, Object?>? extra]) => {
  'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'name': record.name.wireName,
  'occurredAt': '2026-10-19T00:00:00Z',
  'attributes': {...record.attributes, ...?extra},
};

void main() {
  test('first attempts keep the old shape; retries carry their number', () {
    final first = AnalyticsRecord.syncStarted(
      AnalyticsSyncOperation.backup,
      trigger: AnalyticsTrigger.manual,
    );
    final retry = AnalyticsRecord.syncStarted(
      AnalyticsSyncOperation.backup,
      trigger: AnalyticsTrigger.manual,
      attempt: 3,
    );
    expect(first.attributes, {'operation': 'backup', 'trigger': 'manual'});
    expect(retry.attributes['attempt'], 3);
    expect(isSafeAnalyticsEvent(_event(first)), isTrue);
    expect(isSafeAnalyticsEvent(_event(retry)), isTrue);
  });

  test('terminal records, including abandoned, validate with and without attempt', () {
    final records = [
      AnalyticsRecord.sync(
        AnalyticsSyncOperation.restore,
        trigger: AnalyticsTrigger.startup,
        outcome: AnalyticsOutcome.succeeded,
        durationMs: 10,
        attempt: 2,
      ),
      AnalyticsRecord.sync(
        AnalyticsSyncOperation.restore,
        trigger: AnalyticsTrigger.startup,
        outcome: AnalyticsOutcome.failed,
        durationMs: 10,
      ),
      AnalyticsRecord.syncAbandoned(
        AnalyticsSyncOperation.restore,
        trigger: AnalyticsTrigger.startup,
        reason: AnalyticsSyncAbandonReason.sessionChanged,
        durationMs: 10,
      ),
    ];
    for (final record in records) {
      expect(isSafeAnalyticsEvent(_event(record)), isTrue, reason: '${record.name}');
    }
    expect(records.last.name.wireName, 'sync_abandoned');
  });

  test('invalid attempt numbers and unknown reasons are rejected', () {
    final started = AnalyticsRecord.syncStarted(
      AnalyticsSyncOperation.backup,
      trigger: AnalyticsTrigger.manual,
    );
    for (final bad in [0, 1, 7, '2', null, 2.0]) {
      expect(isSafeAnalyticsEvent(_event(started, {'attempt': bad})), isFalse, reason: '$bad');
    }
    final abandoned = AnalyticsRecord.syncAbandoned(
      AnalyticsSyncOperation.backup,
      trigger: AnalyticsTrigger.manual,
      reason: AnalyticsSyncAbandonReason.sessionChanged,
      durationMs: 1,
    );
    expect(isSafeAnalyticsEvent(_event(abandoned, {'reason': 'crash'})), isFalse);
  });
}
