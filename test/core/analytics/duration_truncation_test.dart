import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _event(AnalyticsRecord record) => {
  'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'name': record.name.wireName,
  'occurredAt': '2026-10-19T00:00:00Z',
  'attributes': record.attributes,
};

void main() {
  test('119999 / 120000 / 120001 and longer durations are distinguished', () {
    Map<String, Object> attributes(int ms) =>
        AnalyticsRecord.appLoad(durationMs: ms).attributes;

    expect(attributes(119999), {'durationMs': 119999});
    expect(attributes(120000), {'durationMs': 120000});
    expect(attributes(120001), {
      'durationMs': 120000,
      'durationTruncated': true,
    });
    expect(attributes(9000000), {
      'durationMs': 120000,
      'durationTruncated': true,
    });
    expect(attributes(-5), {'durationMs': 0});
  });

  test('every duration-bearing record uses the same truncation meaning', () {
    final records = [
      AnalyticsRecord.eventEditorCompleted(
        AnalyticsEditorMode.create,
        outcome: AnalyticsOutcome.succeeded,
        durationMs: 200000,
      ),
      AnalyticsRecord.eventSave(
        AnalyticsOperation.create,
        succeeded: true,
        durationMs: 200000,
      ),
      AnalyticsRecord.eventSave(
        AnalyticsOperation.create,
        succeeded: false,
        durationMs: 200000,
      ),
      AnalyticsRecord.sync(
        AnalyticsSyncOperation.backup,
        trigger: AnalyticsTrigger.manual,
        outcome: AnalyticsOutcome.succeeded,
        durationMs: 200000,
      ),
      AnalyticsRecord.sync(
        AnalyticsSyncOperation.backup,
        trigger: AnalyticsTrigger.manual,
        outcome: AnalyticsOutcome.failed,
        durationMs: 200000,
      ),
      AnalyticsRecord.slowInteraction(
        interaction: 'sync',
        durationMs: 200000,
      ),
    ];
    for (final record in records) {
      expect(record.attributes['durationMs'], 120000);
      expect(record.attributes['durationTruncated'], true);
      expect(isSafeAnalyticsEvent(_event(record)), isTrue, reason: '${record.name}');
    }
  });

  test('older records without the flag and exact 120000 remain valid', () {
    final legacy = _event(AnalyticsRecord.appLoad(durationMs: 120000));
    expect((legacy['attributes'] as Map).containsKey('durationTruncated'), isFalse);
    expect(isSafeAnalyticsEvent(legacy), isTrue);
  });

  test('flag is rejected when false, mistyped, or on events without durations', () {
    final base = _event(AnalyticsRecord.appLoad(durationMs: 5));
    for (final bad in [false, 'true', 1, null]) {
      final event = {
        ...base,
        'attributes': {'durationMs': 5, 'durationTruncated': bad},
      };
      expect(isSafeAnalyticsEvent(event), isFalse, reason: '$bad');
    }
    final screen = _event(AnalyticsRecord.screenView(AnalyticsScreen.calendar));
    expect(
      isSafeAnalyticsEvent({
        ...screen,
        'attributes': {'screen': 'calendar', 'durationTruncated': true},
      }),
      isFalse,
    );
    expect(
      isSafeAnalyticsEvent({
        ...base,
        'attributes': {'durationMs': 120001},
      }),
      isFalse,
    );
    expect(
      isSafeAnalyticsEvent({
        ...base,
        'attributes': {'durationTruncated': true},
      }),
      isFalse,
    );
  });
}
