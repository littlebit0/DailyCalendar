import 'dart:convert';
import 'dart:ui';

import 'package:daily/core/analytics/privacy_analytics_service.dart';
import 'package:daily/core/analytics/product_analytics.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _baseline = DateTime.utc(2026, 10, 19, 12);

/// A frame that took [totalMs] and finished at [wall] (a wall-clock time, not
/// the engine's monotonic clock, as `FramePhase.rasterFinishWallTime` is).
FrameTiming _frame(int totalMs, int number, {DateTime? wall}) => FrameTiming(
  vsyncStart: 0,
  buildStart: 0,
  buildFinish: totalMs * 500,
  rasterStart: totalMs * 500,
  rasterFinish: totalMs * 1000,
  rasterFinishWallTime: (wall ?? _baseline).microsecondsSinceEpoch,
  frameNumber: number,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<(PrivacyAnalyticsService, List<Map<String, dynamic>>)> create({
    required double refreshRate,
    bool foreground = true,
    int status = 202,
  }) async {
    SharedPreferences.setMockInitialValues({'anonymousAnalyticsEnabled': true});
    final events = <Map<String, dynamic>>[];
    final service = PrivacyAnalyticsService(
      preferences: await SharedPreferences.getInstance(),
      endpoint: Uri.parse('https://analytics.example.com/v1/events'),
      environmentLoader: () async => const AnalyticsEnvironment(
        appVersion: '4.1.2',
        platform: 'ios',
        osMajor: 26,
      ),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(isSafeAnalyticsBatch(body), isTrue);
        events.addAll((body['events'] as List).cast<Map<String, dynamic>>());
        return http.Response('{}', status);
      }),
      refreshRateProvider: () => refreshRate,
      foregroundProvider: () => foreground,
      buildMode: AnalyticsBuildMode.profile,
    );
    addTearDown(service.dispose);
    await service.initialize();
    return (service, events);
  }

  Map<String, dynamic> summary(List<Map<String, dynamic>> events) =>
      (events.singleWhere((e) => e['name'] == 'frame_summary')['attributes']
          as Map<String, dynamic>);

  // The same 20 ms frame is jank on a 120 Hz display but fine on 60 Hz.
  for (final entry in {60.0: 0, 120.0: 10, 144.0: 10}.entries) {
    test('${entry.key} Hz judges the same frames against its own budget', () async {
      final (service, events) = await create(refreshRate: entry.key);
      PlatformDispatcher.instance.onReportTimings!([
        for (var i = 0; i < 10; i++) _frame(20, i),
        for (var i = 10; i < 20; i++) _frame(8, i),
      ]);
      await service.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await service.flush();
      final attributes = summary(events);
      expect(attributes['frameCount'], 20);
      expect(attributes['slowFrameCount'], entry.value);
      expect(attributes['refreshRateHz'], entry.key.round());
      expect(attributes['buildMode'], 'profile');
      expect(attributes['durationMs'], 20);
    });
  }

  test('a window with no slow frames still reports its frame total', () async {
    final (service, events) = await create(refreshRate: 60);
    PlatformDispatcher.instance.onReportTimings!([
      for (var i = 0; i < 30; i++) _frame(10, i),
    ]);
    await service.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.flush();
    final attributes = summary(events);
    expect(attributes['frameCount'], 30);
    expect(attributes['slowFrameCount'], 0);
  });

  test('frames drawn outside the foreground are not counted', () async {
    final (service, events) = await create(refreshRate: 60, foreground: false);
    PlatformDispatcher.instance.onReportTimings!([_frame(100, 1)]);
    await service.flush();
    expect(events.where((e) => e['name'] == 'frame_summary'), isEmpty);
  });

  test('summary records stay privacy-safe and bounded', () {
    final record = AnalyticsRecord.frameSummary(
      frameCount: 5,
      slowFrameCount: 9,
      maxFrameMs: 500000,
      refreshRateHz: 1000,
      buildMode: AnalyticsBuildMode.release,
    );
    expect(record.attributes['slowFrameCount'], 5);
    expect(record.attributes['refreshRateHz'], 240);
    expect(record.attributes['durationTruncated'], true);
    expect(
      isSafeAnalyticsEvent({
        'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'name': 'frame_summary',
        'occurredAt': '2026-10-19T00:00:00Z',
        'attributes': {...record.attributes, 'slowFrameCount': 6},
      }),
      isFalse,
    );
  });

  test('each frame is judged by the lifecycle state when it ran', () async {
    final (service, events) = await create(refreshRate: 60);
    // Backgrounded 1 s after the baseline, foregrounded again 5 s after it.
    service.noteLifecycleState(
      AppLifecycleState.paused,
      at: _baseline.add(const Duration(seconds: 1)),
    );
    service.noteLifecycleState(
      AppLifecycleState.resumed,
      at: _baseline.add(const Duration(seconds: 5)),
    );
    // One delayed batch carrying frames from all three periods.
    PlatformDispatcher.instance.onReportTimings!([
      _frame(10, 1, wall: _baseline),
      _frame(10, 2, wall: _baseline.add(const Duration(seconds: 2))),
      _frame(10, 3, wall: _baseline.add(const Duration(seconds: 3))),
      _frame(50, 4, wall: _baseline.add(const Duration(seconds: 6))),
    ]);
    await service.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.flush();
    final attributes = summary(events);
    // The two frames that ran while backgrounded are not counted, although the
    // app is in the foreground again when the batch is delivered.
    expect(attributes['frameCount'], 2);
    expect(attributes['slowFrameCount'], 1);
  });

  test('deleting analytics data also deletes the frames counted so far', () async {
    final (service, events) = await create(refreshRate: 60);
    PlatformDispatcher.instance.onReportTimings!([
      for (var i = 0; i < 5; i++) _frame(40, i),
    ]);
    await service.deletePendingData();
    await service.flush();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.flush();
    expect(events.where((e) => e['name'] == 'frame_summary'), isEmpty);
  });

  test('withdrawing consent drops the open frame window for good', () async {
    final (service, events) = await create(refreshRate: 60);
    PlatformDispatcher.instance.onReportTimings!([
      for (var i = 0; i < 5; i++) _frame(40, i),
    ]);
    await service.setEnabled(false);
    await service.setEnabled(true); // re-enabling flushes immediately
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await service.flush();
    expect(events.where((e) => e['name'] == 'frame_summary'), isEmpty);
  });

  test('two windows with identical numbers are both kept', () async {
    // The receiver is down, so the first summary stays queued.
    final (service, events) = await create(refreshRate: 60, status: 503);
    for (var window = 0; window < 2; window++) {
      PlatformDispatcher.instance.onReportTimings!([
        for (var i = 0; i < 5; i++) _frame(10, i),
      ]);
      await service.flush(); // closes the window and records the summary
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(events.where((e) => e['name'] == 'frame_summary'), isNotEmpty);
    expect(service.pendingEventCount, 2);
  });
}
