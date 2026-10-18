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

  test('the flag is only valid together with the capped duration', () {
    Map<String, Object?> event(int ms, {bool flag = true}) => {
      'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'name': 'app_load_completed',
      'occurredAt': '2026-10-19T00:00:00Z',
      'attributes': {'durationMs': ms, if (flag) 'durationTruncated': true},
    };
    expect(isSafeAnalyticsEvent(event(120000)), isTrue);
    expect(isSafeAnalyticsEvent(event(5)), isFalse);
    expect(isSafeAnalyticsEvent(event(119999)), isFalse);
    expect(isSafeAnalyticsEvent(event(5, flag: false)), isTrue);
  });

  test('event_save records without a phase (older apps) stay valid', () {
    Map<String, Object?> save(Map<String, Object?> attributes) => {
      'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'name': 'event_save_succeeded',
      'occurredAt': '2026-10-19T00:00:00Z',
      'attributes': attributes,
    };
    expect(isSafeAnalyticsEvent(save({'operation': 'create', 'durationMs': 5})), isTrue);
    expect(
      isSafeAnalyticsEvent(
        save({'operation': 'create', 'phase': 'database', 'durationMs': 5}),
      ),
      isTrue,
    );
    expect(
      isSafeAnalyticsEvent(
        save({'operation': 'create', 'phase': 'later', 'durationMs': 5}),
      ),
      isFalse,
    );
  });
}
