import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:daily/core/diagnostics/startup_timing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _event(AnalyticsRecord record) => {
  'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'name': record.name.wireName,
  'occurredAt': '2026-10-19T00:00:00Z',
  'attributes': record.attributes,
};

void main() {
  test('each milestone is its own event, apart from app_load_completed', () {
    final frame = AnalyticsRecord.startupMilestone(
      AnalyticsStartupMilestone.firstCalendarFrame,
      durationMs: 850,
    );
    final local = AnalyticsRecord.startupMilestone(
      AnalyticsStartupMilestone.localCalendarReady,
      durationMs: 1200,
    );
    expect(frame.name.wireName, 'startup_milestone');
    expect(frame.attributes, {
      'milestone': 'firstCalendarFrame',
      'durationMs': 850,
    });
    expect(local.attributes['milestone'], 'localCalendarReady');
    expect(AnalyticsRecord.appLoad(durationMs: 300).name.wireName,
        'app_load_completed');
    expect(isSafeAnalyticsEvent(_event(frame)), isTrue);
    expect(isSafeAnalyticsEvent(_event(local)), isTrue);
  });

  test('unknown milestones and missing duration are rejected', () {
    final base = _event(
      AnalyticsRecord.startupMilestone(
        AnalyticsStartupMilestone.firstCalendarFrame,
        durationMs: 1,
      ),
    );
    expect(
      isSafeAnalyticsEvent({
        ...base,
        'attributes': {'milestone': 'syncDone', 'durationMs': 1},
      }),
      isFalse,
    );
    expect(
      isSafeAnalyticsEvent({
        ...base,
        'attributes': {'milestone': 'firstCalendarFrame'},
      }),
      isFalse,
    );
  });

  test('a milestone is claimed once per process, so rebuilds do not repeat it', () {
    StartupTiming.resetClaims();
    addTearDown(StartupTiming.resetClaims);
    expect(StartupTiming.claim(StartupStage.firstCalendarFrame), isTrue);
    expect(StartupTiming.claim(StartupStage.firstCalendarFrame), isFalse);
    expect(StartupTiming.claim(StartupStage.localCalendar), isTrue);
    expect(StartupTiming.claim(StartupStage.localCalendar), isFalse);
    expect(StartupTiming.sinceLaunchMs, greaterThanOrEqualTo(0));
  });
}
